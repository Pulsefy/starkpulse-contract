// Event Filtering Utility
#[starknet::contract]
mod EventFilter {
    use starknet::ContractAddress;
    use array::ArrayTrait;
    use super::{
        StandardEvent, StandardEventMetadata,
        IEventSystemDispatcher, IEventSystemDispatcherTrait
    };
    
    #[storage]
    struct Storage {
        event_system_address: ContractAddress,
    }
    
    #[derive(Drop, Serde)]
    struct EventFilterCriteria {
        categories: Array<felt252>,
        event_types: Array<felt252>,
        users: Array<ContractAddress>,
        contracts: Array<ContractAddress>,
        severity_min: u8,
        severity_max: u8,
        start_time: u64,
        end_time: u64,
        versions: Array<felt252>,
        correlation_ids: Array<felt252>,
    }
    
    #[constructor]
    fn constructor(ref self: ContractState, event_system_address: ContractAddress) {
        self.event_system_address.write(event_system_address);
    }
    
    #[external(v0)]
    impl EventFilterImpl of IEventFilter<ContractState> {
        fn filter_events(
            self: @ContractState,
            criteria: EventFilterCriteria
        ) -> Array<StandardEvent> {
            let mut filtered_events = ArrayTrait::new();
            let event_system = IEventSystemDispatcher {
                contract_address: self.event_system_address.read()
            };
            
            // Apply multiple filter criteria
            // This would iterate through categories and apply all filters
            let mut i = 0;
            while i < criteria.categories.len() {
                let category = *criteria.categories.at(i);
                
                // Get events for this category
                let category_events = event_system.get_events_by_filter(
                    category,
                    0, // All event types for now
                    starknet::contract_address_const::<0>(), // All users
                    criteria.start_time,
                    criteria.end_time,
                    0 // All versions
                );
                
                // Apply additional filters
                let mut j = 0;
                while j < category_events.len() {
                    let event = category_events.at(j);
                    if self._matches_criteria(event, @criteria) {
                        filtered_events.append(*event);
                    }
                    j += 1;
                };
                
                i += 1;
            };
            
            filtered_events
        }
        
        fn get_events_by_user(
            self: @ContractState,
            user: ContractAddress,
            start_time: u64,
            end_time: u64
        ) -> Array<StandardEvent> {
            let event_system = IEventSystemDispatcher {
                contract_address: self.event_system_address.read()
            };
            
            event_system.get_events_by_filter(
                0, // All categories
                0, // All event types
                user,
                start_time,
                end_time,
                0 // All versions
            )
        }
        
        fn get_events_by_severity(
            self: @ContractState,
            min_severity: u8,
            max_severity: u8,
            start_time: u64,
            end_time: u64
        ) -> Array<StandardEvent> {
            let criteria = EventFilterCriteria {
                categories: array![],
                event_types: array![],
                users: array![],
                contracts: array![],
                severity_min: min_severity,
                severity_max: max_severity,
                start_time,
                end_time,
                versions: array![],
                correlation_ids: array![],
            };
            
            self.filter_events(criteria)
        }
    }
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _matches_criteria(
            self: @ContractState,
            event: @StandardEvent,
            criteria: @EventFilterCriteria
        ) -> bool {
            // Check severity range
            if event.metadata.severity < *criteria.severity_min ||
               event.metadata.severity > *criteria.severity_max {
                return false;
            }
            
            // Check time range
            if event.metadata.timestamp < *criteria.start_time ||
               event.metadata.timestamp > *criteria.end_time {
                return false;
            }
            
            // Check event types if specified
            if criteria.event_types.len() > 0 {
                let mut found = false;
                let mut i = 0;
                while i < criteria.event_types.len() {
                    if *event.event_type == *criteria.event_types.at(i) {
                        found = true;
                        break;
                    }
                    i += 1;
                };
                if !found {
                    return false;
                }
            }
            
            // Check users if specified
            if criteria.users.len() > 0 {
                let mut found = false;
                let mut i = 0;
                while i < criteria.users.len() {
                    if *event.user == *criteria.users.at(i) {
                        found = true;
                        break;
                    }
                    i += 1;
                };
                if !found {
                    return false;
                }
            }
            
            true
        }
    }
}

#[starknet::interface]
trait IEventFilter<TContractState> {
    fn filter_events(
        self: @TContractState,
        criteria: EventFilterCriteria
    ) -> Array<StandardEvent>;
    
    fn get_events_by_user(
        self: @TContractState,
        user: ContractAddress,
        start_time: u64,
        end_time: u64
    ) -> Array<StandardEvent>;
    
    fn get_events_by_severity(
        self: @TContractState,
        min_severity: u8,
        max_severity: u8,
        start_time: u64,
        end_time: u64
    ) -> Array<StandardEvent>;
}