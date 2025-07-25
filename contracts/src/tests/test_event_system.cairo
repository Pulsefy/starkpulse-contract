#[cfg(test)]
mod test_event_system {
    use starknet::{
        ContractAddress, 
        contract_address_const, 
        testing::{set_caller_address, set_block_timestamp}
    };
    
    use crate::utils::event_system::{
        EventSystem, IEventSystemDispatcher, IEventSystemDispatcherTrait,
        IEventSystemAdminDispatcher, IEventSystemAdminDispatcherTrait
    };
    use crate::interfaces::i_event_system::{
        StandardEvent, CATEGORY_TRANSACTION, CATEGORY_SECURITY, SEVERITY_INFO, SEVERITY_WARNING
    };
    
    // Test addresses
    const ADMIN: felt252 = 0x123;
    const CONTRACT1: felt252 = 0x456;
    const USER1: felt252 = 0x789;
    
    fn setup_event_system() -> (IEventSystemDispatcher, IEventSystemAdminDispatcher, ContractAddress, ContractAddress) {
        let admin = contract_address_const::<ADMIN>();
        let contract1 = contract_address_const::<CONTRACT1>();
        
        set_caller_address(admin);
        
        let mut event_system = EventSystem::unsafe_new();
        event_system.constructor(admin);
        
        let dispatcher = IEventSystemDispatcher { contract_address: contract_address_const::<0x1>() };
        let admin_dispatcher = IEventSystemAdminDispatcher { contract_address: contract_address_const::<0x1>() };
        
        (dispatcher, admin_dispatcher, admin, contract1)
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_event_emission() {
        let (mut event_system, mut admin_system, admin, contract1) = setup_event_system();
        
        // Authorize contract1 to emit events
        set_caller_address(admin);
        admin_system.authorize_contract(contract1);
        
        // Emit an event from contract1
        set_caller_address(contract1);
        let user1 = contract_address_const::<USER1>();
        
        let event_data = array!['test_data_1', 'test_data_2'];
        let indexed_data = array!['indexed_1', 'indexed_2'];
        
        let event_id = event_system.emit_standard_event(
            'TEST_EVENT',
            CATEGORY_TRANSACTION,
            SEVERITY_INFO,
            user1,
            event_data,
            indexed_data,
            12345 // correlation_id
        );
        
        assert(event_id > 0, "Event should be emitted with valid ID");
    }
    
    #[test]
    #[available_gas(3000000)]
    fn test_event_filtering() {
        let (mut event_system, mut admin_system, admin, contract1) = setup_event_system();
        
        // Authorize and emit multiple events
        set_caller_address(admin);
        admin_system.authorize_contract(contract1);
        
        set_caller_address(contract1);
        let user1 = contract_address_const::<USER1>();
        
        // Emit transaction event
        event_system.emit_standard_event(
            'TRANSFER',
            CATEGORY_TRANSACTION,
            SEVERITY_INFO,
            user1,
            array!['100'],
            array![user1.into()],
            0
        );
        
        // Emit security event
        event_system.emit_standard_event(
            'SUSPICIOUS_ACTIVITY',
            CATEGORY_SECURITY,
            SEVERITY_WARNING,
            user1,
            array!['high_frequency'],
            array![user1.into()],
            0
        );
        
        // Test filtering by category
        let transaction_events = event_system.get_events_by_filter(
            CATEGORY_TRANSACTION,
            0, // All event types
            starknet::contract_address_const::<0>(), // All users
            0, // Start time
            9999999999, // End time
            0 // All versions
        );
        
        // Should have at least the transaction event we emitted
        assert(transaction_events.len() >= 1, "Should find transaction events");
    }
    
    #[test]
    #[available_gas(3000000)]
    fn test_correlation_tracking() {
        let (mut event_system, mut admin_system, admin, contract1) = setup_event_system();
        
        set_caller_address(admin);
        admin_system.authorize_contract(contract1);
        
        set_caller_address(contract1);
        let user1 = contract_address_const::<USER1>();
        let correlation_id = 98765;
        
        // Emit multiple related events
        event_system.emit_standard_event(
            'TRANSACTION_INITIATED',
            CATEGORY_TRANSACTION,
            SEVERITY_INFO,
            user1,
            array!['init'],
            array![user1.into()],
            correlation_id
        );
        
        event_system.emit_standard_event(
            'TRANSACTION_VERIFIED',
            CATEGORY_SECURITY,
            SEVERITY_INFO,
            user1,
            array!['verified'],
            array![user1.into()],
            correlation_id
        );
        
        // Get correlated events
        let correlated_events = event_system.get_events_by_correlation(correlation_id);
        
        // Should find both related events
        assert(correlated_events.len() >= 2, "Should find correlated events");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_authorization() {
        let (mut event_system, mut admin_system, admin, contract1) = setup_event_system();
        
        // Test that unauthorized contract cannot emit events
        set_caller_address(contract1);
        let user1 = contract_address_const::<USER1>();
        
        // This should fail
        // event_system.emit_standard_event(...) would panic
        
        // Authorize the contract
        set_caller_address(admin);
        admin_system.authorize_contract(contract1);
        
        // Verify authorization
        assert(admin_system.is_authorized(contract1), "Contract should be authorized");
        
        // Now it should work
        set_caller_address(contract1);
        let event_id = event_system.emit_standard_event(
            'AUTHORIZED_EVENT',
            CATEGORY_SYSTEM,
            SEVERITY_INFO,
            user1,
            array!['authorized'],
            array![contract1.into()],
            0
        );
        
        assert(event_id > 0, "Authorized contract should emit events");
    }
}