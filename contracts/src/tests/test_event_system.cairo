#[cfg(test)]
mod test_event_system {
    use starknet::{ContractAddress, contract_address_const, testing::set_caller_address};
    use crate::utils::event_system::{EventSystem, IEventSystemDispatcher, IEventSystemDispatcherTrait};
    use crate::interfaces::i_event_system::{CATEGORY_TRANSACTION, SEVERITY_INFO};
    use array::ArrayTrait;
    
    #[test]
    #[available_gas(2000000)]
    fn test_standard_event_emission() {
        let event_system = deploy_event_system();
        let user = contract_address_const::<0x123>();
        
        let mut data = ArrayTrait::new();
        data.append('test_data');
        
        let mut indexed_data = ArrayTrait::new();
        indexed_data.append('test_index');
        
        let event_id = event_system.emit_standard_event(
            'TEST_EVENT',
            CATEGORY_TRANSACTION,
            SEVERITY_INFO,
            user,
            data,
            indexed_data,
            'correlation_123'
        );
        
        assert(event_id != 0, "Event ID should be generated");
    }
    
    #[test]
    #[available_gas(3000000)]
    fn test_event_filtering() {
        let event_system = deploy_event_system();
        let user = contract_address_const::<0x123>();
        
        // Emit multiple events
        emit_test_events(event_system, user);
        
        // Filter by category
        let filtered_events = event_system.get_events_by_filter(
            CATEGORY_TRANSACTION,
            0, // any event type
            user,
            0, // start time
            999999999, // end time
            0 // any version
        );
        
        assert(filtered_events.len() > 0, "Should find filtered events");
    }
    
    #[test]
    #[available_gas(3000000)]
    fn test_correlation_tracking() {
        let event_system = deploy_event_system();
        let user = contract_address_const::<0x123>();
        let correlation_id = 'test_correlation';
        
        // Emit correlated events
        emit_correlated_events(event_system, user, correlation_id);
        
        // Get correlated events
        let correlated_events = event_system.get_events_by_correlation(correlation_id);
        
        assert(correlated_events.len() > 1, "Should find correlated events");
    }
    
    fn deploy_event_system() -> IEventSystemDispatcher {
        let contract = declare("EventSystem");
        let contract_address = contract.deploy(@ArrayTrait::new()).unwrap();
        IEventSystemDispatcher { contract_address }
    }
    
    fn emit_test_events(event_system: IEventSystemDispatcher, user: ContractAddress) {
        // Implementation for test helper
    }
    
    fn emit_correlated_events(event_system: IEventSystemDispatcher, user: ContractAddress, correlation_id: felt252) {
        // Implementation for test helper
    }
}