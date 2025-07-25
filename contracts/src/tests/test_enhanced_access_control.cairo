#[cfg(test)]
mod test_enhanced_access_control {
    use starknet::{
        ContractAddress, 
        contract_address_const, 
        testing::{set_caller_address, set_block_timestamp}
    };
    
    use crate::utils::enhanced_access_control::{
        EnhancedAccessControl, IEnhancedAccessControlDispatcher, IEnhancedAccessControlDispatcherTrait
    };
    use crate::interfaces::i_enhanced_access_control::{
        Permission, TimeConstraint, PERMISSION_READ, PERMISSION_WRITE, PERMISSION_ADMIN,
        TIME_CONSTRAINT_WINDOW, TIME_CONSTRAINT_EXPIRY
    };
    
    // Test addresses
    const ADMIN: felt252 = 0x123;
    const USER1: felt252 = 0x456;
    const USER2: felt252 = 0x789;
    const EVENT_SYSTEM: felt252 = 0xABC;
    
    fn setup_enhanced_access_control() -> (IEnhancedAccessControlDispatcher, ContractAddress, ContractAddress, ContractAddress) {
        let admin = contract_address_const::<ADMIN>();
        let user1 = contract_address_const::<USER1>();
        let user2 = contract_address_const::<USER2>();
        let event_system = contract_address_const::<EVENT_SYSTEM>();
        
        set_caller_address(admin);
        
        let mut contract = EnhancedAccessControl::unsafe_new();
        contract.constructor(admin, event_system);
        
        let dispatcher = IEnhancedAccessControlDispatcher { contract_address: contract_address_const::<0x1>() };
        
        (dispatcher, admin, user1, user2)
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_fine_grained_permissions() {
        let (mut contract, admin, user1, _) = setup_enhanced_access_control();
        
        set_caller_address(admin);
        
        // Grant read permission to user1 for specific resource
        let time_constraint = TimeConstraint {
            constraint_type: TIME_CONSTRAINT_EXPIRY,
            start_time: 0,
            end_time: 9999999999, // Far future
            allowed_days: 0,
            allowed_hours_start: 0,
            allowed_hours_end: 0,
        };
        
        let result = contract.grant_permission(
            user1,
            'PORTFOLIO_DATA',
            'READ_BALANCE',
            PERMISSION_READ,
            time_constraint
        );
        assert(result, "Should grant read permission");
        
        // Check permission
        assert(
            contract.has_permission(user1, 'PORTFOLIO_DATA', 'READ_BALANCE', PERMISSION_READ),
            "User should have read permission"
        );
        
        // Should not have write permission
        assert(
            !contract.has_permission(user1, 'PORTFOLIO_DATA', 'READ_BALANCE', PERMISSION_WRITE),
            "User should not have write permission"
        );
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_time_based_permissions() {
        let (mut contract, admin, user1, _) = setup_enhanced_access_control();
        
        set_caller_address(admin);
        set_block_timestamp(1000);
        
        // Grant permission with time window
        let time_constraint = TimeConstraint {
            constraint_type: TIME_CONSTRAINT_WINDOW,
            start_time: 500,
            end_time: 1500,
            allowed_days: 0,
            allowed_hours_start: 0,
            allowed_hours_end: 0,
        };
        
        contract.grant_permission(
            user1,
            'TRADING_SYSTEM',
            'EXECUTE_TRADE',
            PERMISSION_EXECUTE,
            time_constraint
        );
        
        // Should have permission within time window
        assert(
            contract.has_permission(user1, 'TRADING_SYSTEM', 'EXECUTE_TRADE', PERMISSION_EXECUTE),
            "Should have permission within time window"
        );
        
        // Move outside time window
        set_block_timestamp(2000);
        
        // Should not have permission outside time window
        assert(
            !contract.has_permission(user1, 'TRADING_SYSTEM', 'EXECUTE_TRADE', PERMISSION_EXECUTE),
            "Should not have permission outside time window"
        );
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_permission_delegation() {
        let (mut contract, admin, user1, user2) = setup_enhanced_access_control();
        
        set_caller_address(admin);
        
        // Grant delegation permission to user1
        let time_constraint = TimeConstraint {
            constraint_type: TIME_CONSTRAINT_EXPIRY,
            start_time: 0,
            end_time: 9999999999,
            allowed_days: 0,
            allowed_hours_start: 0,
            allowed_hours_end: 0,
        };
        
        contract.grant_permission(
            user1,
            'ANALYTICS_DATA',
            'VIEW_REPORTS',
            PERMISSION_READ,
            time_constraint
        );
        
        contract.grant_permission(
            user1,
            'ANALYTICS_DATA',
            'VIEW_REPORTS',
            'DELEGATE',
            time_constraint
        );
        
        // User1 delegates permission to user2
        set_caller_address(user1);
        
        let delegation_constraint = TimeConstraint {
            constraint_type: TIME_CONSTRAINT_EXPIRY,
            start_time: 0,
            end_time: get_block_timestamp() + 3600, // 1 hour
            allowed_days: 0,
            allowed_hours_start: 0,
            allowed_hours_end: 0,
        };
        
        let result = contract.delegate_permission(
            user2,
            'ANALYTICS_DATA',
            'VIEW_REPORTS',
            PERMISSION_READ,
            delegation_constraint,
            false, // Cannot redelegate
            get_block_timestamp() + 3600
        );
        assert(result, "Should delegate permission");
        
        // User2 should now have the delegated permission
        assert(
            contract.has_permission(user2, 'ANALYTICS_DATA', 'VIEW_REPORTS', PERMISSION_READ),
            "User2 should have delegated permission"
        );
    }
    
    #[test]
    #[available_gas(3000000)]
    fn test_role_hierarchy() {
        let (mut contract, admin, user1, _) = setup_enhanced_access_control();
        
        set_caller_address(admin);
        
        // Create role hierarchy: SENIOR_ANALYST -> ANALYST
        let result = contract.create_role_hierarchy(
            'ANALYST',
            'SENIOR_ANALYST',
            true // Inherits permissions
        );
        assert(result, "Should create role hierarchy");
        
        // Test would continue with role assignment and permission inheritance
    }
    
    #[test]
    #[available_gas(3000000)]
    fn test_audit_logging() {
        let (mut contract, admin, user1, _) = setup_enhanced_access_control();
        
        set_caller_address(admin);
        
        let time_constraint = TimeConstraint {
            constraint_type: TIME_CONSTRAINT_EXPIRY,
            start_time: 0,
            end_time: 9999999999,
            allowed_days: 0,
            allowed_hours_start: 0,
            allowed_hours_end: 0,
        };
        
        // Grant permission (should create audit log)
        contract.grant_permission(
            user1,
            'TEST_RESOURCE',
            'TEST_ACTION',
            PERMISSION_READ,
            time_constraint
        );
        
        // Get audit logs
        let logs = contract.get_audit_logs(user1, 0, 9999999999);
        assert(logs.len() > 0, "Should have audit logs");
    }
}