#[starknet::contract]
mod AccessControl {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::Map;
    use array::ArrayTrait;
    use option::OptionTrait;

    #[storage]
    struct Storage {
        // (role, account) => bool
        roles: Map<(felt252, ContractAddress), bool>,

        // (role, action_id, resource_id, account) => PermissionDetail
        permissions: Map<(felt252, felt252, felt252, ContractAddress), PermissionDetail>,

        // role => admin_role
        role_admins: Map<felt252, felt252>,

        // role => parent_role
        role_parents: Map<felt252, felt252>,

        admin: ContractAddress,

        // Delegations: (delegator, delegatee, role, action_id, resource_id) => DelegationDetail
        delegations: Map<(ContractAddress, ContractAddress, felt252, felt252, felt252), DelegationDetail>,

        // Audit logs: indexed by a monotonic counter
        audit_counter: u128,
        audit_logs: Map<u128, AuditEvent>,
    }

    // Permission with time constraints
    struct PermissionDetail {
        active: bool,
        start_time: u64,
        end_time: u64,
    }

    // Delegation with time and scope
    struct DelegationDetail {
        valid: bool,
        start_time: u64,
        end_time: u64,
    }

    // Audit event structure
    struct AuditEvent {
        event_type: felt252,
        operator: ContractAddress,
        target: ContractAddress,
        role: felt252,
        action_id: felt252,
        resource_id: felt252,
        timestamp: u64,
        extra: felt252, // e.g., "GRANT", "REVOKE", "DELEGATE"
    }

    // Role constants
    const ADMIN_ROLE: felt252 = 'ADMIN_ROLE';
    const PORTFOLIO_MANAGER_ROLE: felt252 = 'PORTFOLIO_MANAGER_ROLE';
    const TRANSACTION_MONITOR_ROLE: felt252 = 'TRANSACTION_MONITOR_ROLE';

    // Example actions/resources
    // const ACTION_TRANSFER: felt252 = 0x01;
    // const RESOURCE_PORTFOLIO: felt252 = 0xA1;

    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        self.admin.write(admin_address);

        // Set up role hierarchy
        self.roles.write((ADMIN_ROLE, admin_address), true);
        self.role_admins.write(PORTFOLIO_MANAGER_ROLE, ADMIN_ROLE);
        self.role_admins.write(TRANSACTION_MONITOR_ROLE, ADMIN_ROLE);

        // Set up role parents (hierarchies)
        self.role_parents.write(PORTFOLIO_MANAGER_ROLE, ADMIN_ROLE);
        self.role_parents.write(TRANSACTION_MONITOR_ROLE, ADMIN_ROLE);
    }

    // ========== ROLE & PERMISSION MANAGEMENT ==========

    // Query if an account has a role (direct or via parent)
    #[external(v0)]
    fn has_role(self: @ContractState, role: felt252, account: ContractAddress) -> bool {
        if self.roles.read((role, account)) {
            return true;
        }
        // Check parent role recursively
        let mut current = role;
        loop {
            let parent = self.role_parents.read(current);
            if parent == 0 { break; }
            if self.roles.read((parent, account)) {
                return true;
            }
            current = parent;
        }
        false
    }

    // Grant a role to an account
    #[external(v0)]
    fn grant_role(ref self: ContractState, role: felt252, account: ContractAddress) -> bool {
        let caller = get_caller_address();
        let admin_role = self.role_admins.read(role);
        assert(self.has_role(admin_role, caller), 'Not authorized');
        self.roles.write((role, account), true);
        self._log_event('GRANT_ROLE', caller, account, role, 0, 0, 0, 'GRANT');
        true
    }

    // Revoke a role from an account
    #[external(v0)]
    fn revoke_role(ref self: ContractState, role: felt252, account: ContractAddress) -> bool {
        let caller = get_caller_address();
        let admin_role = self.role_admins.read(role);
        assert(self.has_role(admin_role, caller), 'Not authorized');
        self.roles.write((role, account), false);
        self._log_event('REVOKE_ROLE', caller, account, role, 0, 0, 0, 'REVOKE');
        true
    }

    // Renounce own role
    #[external(v0)]
    fn renounce_role(ref self: ContractState, role: felt252) -> bool {
        let caller = get_caller_address();
        self.roles.write((role, caller), false);
        self._log_event('RENOUNCE_ROLE', caller, caller, role, 0, 0, 0, 'RENOUNCE');
        true
    }

    // ========== FINE-GRAINED & TIME-BASED PERMISSIONS ==========

    // Grant permission for an action/resource with time constraints
    #[external(v0)]
    fn grant_permission(
        ref self: ContractState, role: felt252,
        action_id: felt252, resource_id: felt252,
        account: ContractAddress, start_time: u64, end_time: u64
    ) -> bool {
        let caller = get_caller_address();
        let admin_role = self.role_admins.read(role);
        assert(self.has_role(admin_role, caller), 'Not authorized');
        self.permissions.write(
            (role, action_id, resource_id, account),
            PermissionDetail { active: true, start_time, end_time }
        );
        self._log_event('GRANT_PERMISSION', caller, account, role, action_id, resource_id, end_time, 'GRANT');
        true
    }

    // Revoke permission for an action/resource
    #[external(v0)]
    fn revoke_permission(
        ref self: ContractState, role: felt252,
        action_id: felt252, resource_id: felt252, account: ContractAddress
    ) -> bool {
        let caller = get_caller_address();
        let admin_role = self.role_admins.read(role);
        assert(self.has_role(admin_role, caller), 'Not authorized');
        self.permissions.write(
            (role, action_id, resource_id, account),
            PermissionDetail { active: false, start_time: 0, end_time: 0 }
        );
        self._log_event('REVOKE_PERMISSION', caller, account, role, action_id, resource_id, 0, 'REVOKE');
        true
    }

    // Query if an account has permission (checks role, action, resource, and time)
    #[external(v0)]
    fn has_permission(
        self: @ContractState, role: felt252,
        action_id: felt252, resource_id: felt252, account: ContractAddress
    ) -> bool {
        let detail = self.permissions.read((role, action_id, resource_id, account));
        if detail.active {
            let now = get_block_timestamp();
            return now >= detail.start_time && now <= detail.end_time;
        }
        false
    }

    // ========== ROLE HIERARCHY (PARENT-CHILD) MANAGEMENT ==========

    #[external(v0)]
    fn set_role_parent(ref self: ContractState, role: felt252, parent_role: felt252) -> bool {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Not authorized');
        self.role_parents.write(role, parent_role);
        self._log_event('SET_ROLE_PARENT', caller, 0, role, 0, parent_role, 0, 'HIERARCHY');
        true
    }

    #[external(v0)]
    fn set_role_admin(ref self: ContractState, role: felt252, admin_role: felt252) -> bool {
        let caller = get_caller_address();
        assert(caller == self.admin.read(), 'Not authorized');
        self.role_admins.write(role, admin_role);
        self._log_event('SET_ROLE_ADMIN', caller, 0, role, 0, admin_role, 0, 'ADMIN');
        true
    }

    // ========== PERMISSION DELEGATION ==========

    #[external(v0)]
    fn delegate_permission(
        ref self: ContractState, delegatee: ContractAddress, 
        role: felt252, action_id: felt252, resource_id: felt252,
        start_time: u64, end_time: u64
    ) -> bool {
        let caller = get_caller_address();
        // Only allow delegation if caller has that permission and for a sub-window
        let detail = self.permissions.read((role, action_id, resource_id, caller));
        assert(detail.active, 'No base permission');
        assert(start_time >= detail.start_time && end_time <= detail.end_time, 'Invalid time window');
        self.delegations.write(
            (caller, delegatee, role, action_id, resource_id),
            DelegationDetail { valid: true, start_time, end_time }
        );
        self._log_event('DELEGATE_PERMISSION', caller, delegatee, role, action_id, resource_id, end_time, 'DELEGATE');
        true
    }

    // Query if an account has delegated permission
    #[external(v0)]
    fn has_delegated_permission(
        self: @ContractState, delegator: ContractAddress, delegatee: ContractAddress,
        role: felt252, action_id: felt252, resource_id: felt252
    ) -> bool {
        let d = self.delegations.read((delegator, delegatee, role, action_id, resource_id));
        if d.valid {
            let now = get_block_timestamp();
            return now >= d.start_time && now <= d.end_time;
        }
        false
    }

    // ========== AUDIT LOGGING ==========

    fn _log_event(
        ref self: ContractState, event_type: felt252, operator: ContractAddress, target: ContractAddress,
        role: felt252, action_id: felt252, resource_id: felt252, extra: felt252
    ) {
        let ts = get_block_timestamp();
        let counter = self.audit_counter.read();
        self.audit_logs.write(counter, AuditEvent {
            event_type, operator, target, role, action_id, resource_id, timestamp: ts, extra
        });
        self.audit_counter.write(counter + 1);
    }

    #[external(v0)]
    fn get_audit_log(self: @ContractState, idx: u128) -> AuditEvent {
        self.audit_logs.read(idx)
    }
}