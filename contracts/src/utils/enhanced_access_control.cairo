#[starknet::contract]
mod EnhancedAccessControl {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::Map;
    use array::ArrayTrait;
    use super::{
        IEnhancedAccessControl, Permission, TimeConstraint, RoleHierarchy,
        DelegatedPermission, AccessAuditLog, PERMISSION_READ, PERMISSION_WRITE,
        PERMISSION_EXECUTE, PERMISSION_ADMIN, PERMISSION_DELEGATE,
        TIME_CONSTRAINT_NONE, TIME_CONSTRAINT_WINDOW, TIME_CONSTRAINT_SCHEDULE,
        TIME_CONSTRAINT_EXPIRY
    };
    use crate::interfaces::i_event_system::{IEventSystemDispatcher, IEventSystemDispatcherTrait};
    use crate::interfaces::i_event_system::{CATEGORY_SECURITY, SEVERITY_INFO, SEVERITY_WARNING};
    
    #[storage]
    struct Storage {
        // Fine-grained permissions: (account, resource, action) -> Permission
        permissions: Map<(ContractAddress, felt252, felt252), Permission>,
        
        // Time constraints: (account, resource, action) -> TimeConstraint
        time_constraints: Map<(ContractAddress, felt252, felt252), TimeConstraint>,
        
        // Role hierarchies: role -> RoleHierarchy
        role_hierarchies: Map<felt252, RoleHierarchy>,
        
        // Account roles: (account, role) -> bool
        account_roles: Map<(ContractAddress, felt252), bool>,
        
        // Delegated permissions: (delegatee, resource, action) -> DelegatedPermission
        delegated_permissions: Map<(ContractAddress, felt252, felt252), DelegatedPermission>,
        
        // Audit logs: log_id -> AccessAuditLog
        audit_logs: Map<felt252, AccessAuditLog>,
        audit_log_counter: felt252,
        
        // Admin and system addresses
        admin: ContractAddress,
        event_system: ContractAddress,
        
        // Legacy role support
        roles: Map<(felt252, ContractAddress), bool>,
        role_admins: Map<felt252, felt252>,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PermissionGranted: PermissionGranted,
        PermissionRevoked: PermissionRevoked,
        PermissionDelegated: PermissionDelegated,
        DelegationRevoked: DelegationRevoked,
        RoleHierarchyCreated: RoleHierarchyCreated,
        AccessAttempt: AccessAttempt,
    }
    
    #[derive(Drop, starknet::Event)]
    struct PermissionGranted {
        #[key]
        account: ContractAddress,
        #[key]
        resource: felt252,
        #[key]
        action: felt252,
        level: felt252,
        granted_by: ContractAddress,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct PermissionRevoked {
        #[key]
        account: ContractAddress,
        #[key]
        resource: felt252,
        #[key]
        action: felt252,
        revoked_by: ContractAddress,
        timestamp: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct PermissionDelegated {
        #[key]
        delegator: ContractAddress,
        #[key]
        delegatee: ContractAddress,
        #[key]
        resource: felt252,
        action: felt252,
        level: felt252,
        expires_at: u64,
    }
    
    #[derive(Drop, starknet::Event)]
    struct DelegationRevoked {
        #[key]
        delegator: ContractAddress,
        #[key]
        delegatee: ContractAddress,
        #[key]
        resource: felt252,
        action: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    struct RoleHierarchyCreated {
        #[key]
        child_role: felt252,
        #[key]
        parent_role: felt252,
        inherits_permissions: bool,
    }
    
    #[derive(Drop, starknet::Event)]
    struct AccessAttempt {
        #[key]
        account: ContractAddress,
        #[key]
        resource: felt252,
        action: felt252,
        success: bool,
        timestamp: u64,
    }
    
    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin_address: ContractAddress,
        event_system_address: ContractAddress
    ) {
        self.admin.write(admin_address);
        self.event_system.write(event_system_address);
        self.audit_log_counter.write(0);
        
        // Grant admin full permissions
        let admin_permission = Permission {
            resource: '*',
            action: '*',
            level: PERMISSION_ADMIN,
            granted_at: get_block_timestamp(),
            granted_by: admin_address,
        };
        
        self.permissions.write((admin_address, '*', '*'), admin_permission);
        
        // Log initial setup
        self._log_audit(
            'SYSTEM_INIT',
            admin_address,
            admin_address,
            '*',
            PERMISSION_ADMIN,
            true,
            'Initial admin setup'
        );
    }
    
    #[external(v0)]
    impl EnhancedAccessControlImpl of IEnhancedAccessControl<ContractState> {
        fn grant_permission(
            ref self: ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252,
            level: felt252,
            time_constraint: TimeConstraint
        ) -> bool {
            let caller = get_caller_address();
            
            // Check if caller has admin permission for this resource
            assert(
                self._has_admin_permission(caller, resource),
                'Insufficient permissions to grant'
            );
            
            let permission = Permission {
                resource,
                action,
                level,
                granted_at: get_block_timestamp(),
                granted_by: caller,
            };
            
            self.permissions.write((account, resource, action), permission);
            self.time_constraints.write((account, resource, action), time_constraint);
            
            // Emit event
            self.emit(PermissionGranted {
                account,
                resource,
                action,
                level,
                granted_by: caller,
                timestamp: get_block_timestamp(),
            });
            
            // Log audit
            self._log_audit(
                'GRANT_PERMISSION',
                caller,
                account,
                resource,
                level,
                true,
                'Permission granted'
            );
            
            // Emit to event system
            self._emit_to_event_system(
                'PERMISSION_GRANTED',
                array![account.into(), resource, action, level],
                array![caller.into(), resource]
            );
            
            true
        }
        
        fn revoke_permission(
            ref self: ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252
        ) -> bool {
            let caller = get_caller_address();
            
            // Check if caller has admin permission for this resource
            assert(
                self._has_admin_permission(caller, resource),
                'Insufficient permissions to revoke'
            );
            
            // Clear permission and time constraint
            let zero_permission = Permission {
                resource: 0,
                action: 0,
                level: 0,
                granted_at: 0,
                granted_by: starknet::contract_address_const::<0>(),
            };
            let zero_constraint = TimeConstraint {
                constraint_type: TIME_CONSTRAINT_NONE,
                start_time: 0,
                end_time: 0,
                allowed_days: 0,
                allowed_hours_start: 0,
                allowed_hours_end: 0,
            };
            
            self.permissions.write((account, resource, action), zero_permission);
            self.time_constraints.write((account, resource, action), zero_constraint);
            
            // Emit event
            self.emit(PermissionRevoked {
                account,
                resource,
                action,
                revoked_by: caller,
                timestamp: get_block_timestamp(),
            });
            
            // Log audit
            self._log_audit(
                'REVOKE_PERMISSION',
                caller,
                account,
                resource,
                'REVOKED',
                true,
                'Permission revoked'
            );
            
            true
        }
        
        fn has_permission(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252,
            level: felt252
        ) -> bool {
            // Check direct permission
            if self._check_direct_permission(account, resource, action, level) {
                if self._check_time_constraint(account, resource, action) {
                    return true;
                }
            }
            
            // Check delegated permission
            if self._check_delegated_permission(account, resource, action, level) {
                return true;
            }
            
            // Check inherited permission through role hierarchy
            if self._check_inherited_permission(account, resource, action, level) {
                return true;
            }
            
            false
        }
        
        fn create_role_hierarchy(
            ref self: ContractState,
            child_role: felt252,
            parent_role: felt252,
            inherits_permissions: bool
        ) -> bool {
            let caller = get_caller_address();
            
            // Only admin can create role hierarchies
            assert(caller == self.admin.read(), 'Only admin can create hierarchies');
            
            let hierarchy = RoleHierarchy {
                role: child_role,
                parent_role,
                level: self._calculate_hierarchy_level(parent_role) + 1,
                inherits_permissions,
            };
            
            self.role_hierarchies.write(child_role, hierarchy);
            
            // Emit event
            self.emit(RoleHierarchyCreated {
                child_role,
                parent_role,
                inherits_permissions,
            });
            
            true
        }
        
        fn get_effective_permissions(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252
        ) -> Array<Permission> {
            let mut permissions = ArrayTrait::new();
            
            // This would need to iterate through all possible actions
            // Implementation would collect all permissions for the account/resource
            
            permissions
        }
        
        fn is_permission_active(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252
        ) -> bool {
            self._check_time_constraint(account, resource, action)
        }
        
        fn delegate_permission(
            ref self: ContractState,
            delegatee: ContractAddress,
            resource: felt252,
            action: felt252,
            level: felt252,
            time_constraint: TimeConstraint,
            can_redelegate: bool,
            expires_at: u64
        ) -> bool {
            let caller = get_caller_address();
            
            // Check if caller has the permission and delegation rights
            assert(
                self.has_permission(caller, resource, action, level),
                'Cannot delegate permission you do not have'
            );
            
            assert(
                self.has_permission(caller, resource, action, PERMISSION_DELEGATE),
                'No delegation rights for this permission'
            );
            
            let permission = Permission {
                resource,
                action,
                level,
                granted_at: get_block_timestamp(),
                granted_by: caller,
            };
            
            let delegation = DelegatedPermission {
                delegator: caller,
                delegatee,
                permission,
                time_constraint,
                can_redelegate,
                delegation_depth: self._get_delegation_depth(caller, resource, action) + 1,
                expires_at,
            };
            
            // Prevent excessive delegation chains
            assert(delegation.delegation_depth <= 3, 'Delegation chain too deep');
            
            self.delegated_permissions.write((delegatee, resource, action), delegation);
            
            // Emit event
            self.emit(PermissionDelegated {
                delegator: caller,
                delegatee,
                resource,
                action,
                level,
                expires_at,
            });
            
            true
        }
        
        fn revoke_delegation(
            ref self: ContractState,
            delegatee: ContractAddress,
            resource: felt252,
            action: felt252
        ) -> bool {
            let caller = get_caller_address();
            
            let delegation = self.delegated_permissions.read((delegatee, resource, action));
            
            // Only delegator or admin can revoke
            assert(
                caller == delegation.delegator || caller == self.admin.read(),
                'Cannot revoke delegation'
            );
            
            // Clear delegation
            let zero_delegation = DelegatedPermission {
                delegator: starknet::contract_address_const::<0>(),
                delegatee: starknet::contract_address_const::<0>(),
                permission: Permission {
                    resource: 0,
                    action: 0,
                    level: 0,
                    granted_at: 0,
                    granted_by: starknet::contract_address_const::<0>(),
                },
                time_constraint: TimeConstraint {
                    constraint_type: TIME_CONSTRAINT_NONE,
                    start_time: 0,
                    end_time: 0,
                    allowed_days: 0,
                    allowed_hours_start: 0,
                    allowed_hours_end: 0,
                },
                can_redelegate: false,
                delegation_depth: 0,
                expires_at: 0,
            };
            
            self.delegated_permissions.write((delegatee, resource, action), zero_delegation);
            
            // Emit event
            self.emit(DelegationRevoked {
                delegator: delegation.delegator,
                delegatee,
                resource,
                action,
            });
            
            true
        }
        
        fn get_audit_logs(
            self: @ContractState,
            account: ContractAddress,
            start_time: u64,
            end_time: u64
        ) -> Array<AccessAuditLog> {
            let mut logs = ArrayTrait::new();
            
            // Implementation would iterate through audit logs
            // and filter by account and time range
            
            logs
        }
        
        fn get_permission_history(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252
        ) -> Array<AccessAuditLog> {
            let mut history = ArrayTrait::new();
            
            // Implementation would collect all audit logs
            // related to the account and resource
            
            history
        }
    }
    
    // Internal helper functions
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _has_admin_permission(self: @ContractState, account: ContractAddress, resource: felt252) -> bool {
            // Check if account has admin permission for resource or wildcard
            self._check_direct_permission(account, resource, '*', PERMISSION_ADMIN) ||
            self._check_direct_permission(account, '*', '*', PERMISSION_ADMIN)
        }
        
        fn _check_direct_permission(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252,
            level: felt252
        ) -> bool {
            let permission = self.permissions.read((account, resource, action));
            permission.level == level || permission.level == PERMISSION_ADMIN
        }
        
        fn _check_time_constraint(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252
        ) -> bool {
            let constraint = self.time_constraints.read((account, resource, action));
            let current_time = get_block_timestamp();
            
            match constraint.constraint_type {
                TIME_CONSTRAINT_NONE => true,
                TIME_CONSTRAINT_WINDOW => {
                    current_time >= constraint.start_time && current_time <= constraint.end_time
                },
                TIME_CONSTRAINT_EXPIRY => {
                    current_time <= constraint.end_time
                },
                _ => true, // Default to allow if constraint type unknown
            }
        }
        
        fn _check_delegated_permission(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252,
            level: felt252
        ) -> bool {
            let delegation = self.delegated_permissions.read((account, resource, action));
            
            if delegation.delegatee == account {
                let current_time = get_block_timestamp();
                if current_time <= delegation.expires_at {
                    return delegation.permission.level == level || delegation.permission.level == PERMISSION_ADMIN;
                }
            }
            
            false
        }
        
        fn _check_inherited_permission(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252,
            level: felt252
        ) -> bool {
            // Implementation would check role hierarchy and inherited permissions
            // This is a simplified version
            false
        }
        
        fn _calculate_hierarchy_level(self: @ContractState, role: felt252) -> u8 {
            let hierarchy = self.role_hierarchies.read(role);
            if hierarchy.parent_role == 0 {
                0
            } else {
                hierarchy.level
            }
        }
        
        fn _get_delegation_depth(
            self: @ContractState,
            account: ContractAddress,
            resource: felt252,
            action: felt252
        ) -> u8 {
            let delegation = self.delegated_permissions.read((account, resource, action));
            delegation.delegation_depth
        }
        
        fn _log_audit(
            ref self: ContractState,
            action: felt252,
            actor: ContractAddress,
            target: ContractAddress,
            resource: felt252,
            permission: felt252,
            success: bool,
            reason: felt252
        ) {
            let log_id = self.audit_log_counter.read() + 1;
            self.audit_log_counter.write(log_id);
            
            let audit_log = AccessAuditLog {
                timestamp: get_block_timestamp(),
                action,
                actor,
                target,
                resource,
                permission,
                success,
                reason,
                correlation_id: log_id,
            };
            
            self.audit_logs.write(log_id, audit_log);
        }
        
        fn _emit_to_event_system(
            ref self: ContractState,
            event_type: felt252,
            data: Array<felt252>,
            indexed_data: Array<felt252>
        ) {
            let event_system = IEventSystemDispatcher {
                contract_address: self.event_system.read()
            };
            
            event_system.emit_standard_event(
                event_type,
                CATEGORY_SECURITY,
                SEVERITY_INFO,
                get_caller_address(),
                data,
                indexed_data,
                self.audit_log_counter.read()
            );
        }
    }
}