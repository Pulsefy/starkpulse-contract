// Enhanced Access Control Interface
use starknet::ContractAddress;
use array::ArrayTrait;

// Permission granularity levels
const PERMISSION_READ: felt252 = 'READ';
const PERMISSION_WRITE: felt252 = 'WRITE';
const PERMISSION_EXECUTE: felt252 = 'EXECUTE';
const PERMISSION_ADMIN: felt252 = 'ADMIN';
const PERMISSION_DELEGATE: felt252 = 'DELEGATE';

// Time constraint types
const TIME_CONSTRAINT_NONE: u8 = 0;
const TIME_CONSTRAINT_WINDOW: u8 = 1;
const TIME_CONSTRAINT_SCHEDULE: u8 = 2;
const TIME_CONSTRAINT_EXPIRY: u8 = 3;

#[derive(Drop, Serde, starknet::Store)]
struct Permission {
    resource: felt252,
    action: felt252,
    level: felt252, // READ, WRITE, EXECUTE, ADMIN
    granted_at: u64,
    granted_by: ContractAddress,
}

#[derive(Drop, Serde, starknet::Store)]
struct TimeConstraint {
    constraint_type: u8,
    start_time: u64,
    end_time: u64,
    allowed_days: u8, // Bitmask for days of week (1=Mon, 2=Tue, etc.)
    allowed_hours_start: u8, // 0-23
    allowed_hours_end: u8,   // 0-23
}

#[derive(Drop, Serde, starknet::Store)]
struct RoleHierarchy {
    role: felt252,
    parent_role: felt252,
    level: u8, // Hierarchy depth
    inherits_permissions: bool,
}

#[derive(Drop, Serde, starknet::Store)]
struct DelegatedPermission {
    delegator: ContractAddress,
    delegatee: ContractAddress,
    permission: Permission,
    time_constraint: TimeConstraint,
    can_redelegate: bool,
    delegation_depth: u8,
    expires_at: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct AccessAuditLog {
    timestamp: u64,
    action: felt252, // GRANT, REVOKE, DELEGATE, ACCESS_ATTEMPT
    actor: ContractAddress,
    target: ContractAddress,
    resource: felt252,
    permission: felt252,
    success: bool,
    reason: felt252,
    correlation_id: felt252,
}

#[starknet::interface]
trait IEnhancedAccessControl<TContractState> {
    // Fine-grained permission management
    fn grant_permission(
        ref self: TContractState,
        account: ContractAddress,
        resource: felt252,
        action: felt252,
        level: felt252,
        time_constraint: TimeConstraint
    ) -> bool;
    
    fn revoke_permission(
        ref self: TContractState,
        account: ContractAddress,
        resource: felt252,
        action: felt252
    ) -> bool;
    
    fn has_permission(
        self: @TContractState,
        account: ContractAddress,
        resource: felt252,
        action: felt252,
        level: felt252
    ) -> bool;
    
    // Hierarchical role management
    fn create_role_hierarchy(
        ref self: TContractState,
        child_role: felt252,
        parent_role: felt252,
        inherits_permissions: bool
    ) -> bool;
    
    fn get_effective_permissions(
        self: @TContractState,
        account: ContractAddress,
        resource: felt252
    ) -> Array<Permission>;
    
    // Time-based permissions
    fn is_permission_active(
        self: @TContractState,
        account: ContractAddress,
        resource: felt252,
        action: felt252
    ) -> bool;
    
    // Permission delegation
    fn delegate_permission(
        ref self: TContractState,
        delegatee: ContractAddress,
        resource: felt252,
        action: felt252,
        level: felt252,
        time_constraint: TimeConstraint,
        can_redelegate: bool,
        expires_at: u64
    ) -> bool;
    
    fn revoke_delegation(
        ref self: TContractState,
        delegatee: ContractAddress,
        resource: felt252,
        action: felt252
    ) -> bool;
    
    // Audit and monitoring
    fn get_audit_logs(
        self: @TContractState,
        account: ContractAddress,
        start_time: u64,
        end_time: u64
    ) -> Array<AccessAuditLog>;
    
    fn get_permission_history(
        self: @TContractState,
        account: ContractAddress,
        resource: felt252
    ) -> Array<AccessAuditLog>;
}