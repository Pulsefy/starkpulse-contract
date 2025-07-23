// StarkPulse Event System Implementation
#[starknet::contract]
mod EventSystem {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_block_number, get_contract_address};
    use starknet::storage::Map;
    use array::ArrayTrait;
    use crate::interfaces::i_event_system::{
        IEventSystem, StandardEvent, StandardEventMetadata,
        EVENT_VERSION_CURRENT, CATEGORY_SYSTEM, SEVERITY_INFO
    };
    
    #[storage]
    struct Storage {
        events: Map<felt252, StandardEvent>,
        user_events: Map<ContractAddress, Array<felt252>>,
        category_events: Map<felt252, Array<felt252>>,
        correlation_events: Map<felt252, Array<felt252>>,
        event_counter: u64,
        session_counter: u64,
        user_sessions: Map<ContractAddress, felt252>,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StandardEventEmitted: StandardEventEmitted,
        EventSystemInitialized: EventSystemInitialized,
    }
    
    #[derive(Drop, starknet::Event)]
    struct StandardEventEmitted {
        #[key]
        event_id: felt252,
        #[key]
        event_type: felt252,
        #[key]
        category: felt252,
        #[key]
        user: ContractAddress,
        #[key]
        contract_address: ContractAddress,
        version: felt252,
        severity: u8,
        timestamp: u64,
        correlation_id: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    struct EventSystemInitialized {
        contract_address: ContractAddress,
        version: felt252,
        timestamp: u64,
    }
    
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.event_counter.write(0);
        self.session_counter.write(0);
        
        // Emit initialization event
        self.emit(EventSystemInitialized {
            contract_address: get_contract_address(),
            version: EVENT_VERSION_CURRENT,
            timestamp: get_block_timestamp(),
        });
    }
    
    #[abi(embed_v0)]
    impl EventSystemImpl of IEventSystem<ContractState> {
        fn emit_standard_event(
            ref self: ContractState,
            event_type: felt252,
            category: felt252,
            severity: u8,
            user: ContractAddress,
            data: Array<felt252>,
            indexed_data: Array<felt252>,
            correlation_id: felt252
        ) -> felt252 {
            let event_counter = self.event_counter.read();
            let new_counter = event_counter + 1;
            self.event_counter.write(new_counter);
            
            let event_id = new_counter.into();
            let timestamp = get_block_timestamp();
            let block_number = get_block_number();
            let contract_address = get_caller_address();
            
            // Get or create session ID for user
            let session_id = self._get_or_create_session(user);
            
            let metadata = StandardEventMetadata {
                version: EVENT_VERSION_CURRENT,
                category: category,
                severity: severity,
                contract_address: contract_address,
                block_number: block_number,
                timestamp: timestamp,
                correlation_id: correlation_id,
                session_id: session_id,
            };
            
            let standard_event = StandardEvent {
                event_id: event_id,
                event_type: event_type,
                user: user,
                metadata: metadata,
                data: data,
                indexed_data: indexed_data,
            };
            
            // Store event
            self.events.write(event_id, standard_event);
            
            // Update indexes for efficient filtering
            self._update_user_events(user, event_id);
            self._update_category_events(category, event_id);
            self._update_correlation_events(correlation_id, event_id);
            
            // Emit the standardized event
            self.emit(StandardEventEmitted {
                event_id: event_id,
                event_type: event_type,
                category: category,
                user: user,
                contract_address: contract_address,
                version: EVENT_VERSION_CURRENT,
                severity: severity,
                timestamp: timestamp,
                correlation_id: correlation_id,
            });
            
            event_id
        }
        
        fn get_events_by_filter(
            self: @ContractState,
            category: felt252,
            event_type: felt252,
            user: ContractAddress,
            start_time: u64,
            end_time: u64,
            version: felt252
        ) -> Array<StandardEvent> {
            let mut filtered_events = ArrayTrait::new();
            
            // Get events by category first (most efficient filter)
            let category_event_ids = self.category_events.read(category);
            
            let mut i = 0;
            loop {
                if i >= category_event_ids.len() {
                    break;
                }
                
                let event_id = *category_event_ids.at(i);
                let event = self.events.read(event_id);
                
                // Apply filters
                let matches_type = event_type == 0 || event.event_type == event_type;
                let matches_user = user.is_zero() || event.user == user;
                let matches_time = event.metadata.timestamp >= start_time && event.metadata.timestamp <= end_time;
                let matches_version = version == 0 || event.metadata.version == version;
                
                if matches_type && matches_user && matches_time && matches_version {
                    filtered_events.append(event);
                }
                
                i += 1;
            };
            
            filtered_events
        }
        
        fn get_events_by_correlation(
            self: @ContractState,
            correlation_id: felt252
        ) -> Array<StandardEvent> {
            let mut correlated_events = ArrayTrait::new();
            let correlation_event_ids = self.correlation_events.read(correlation_id);
            
            let mut i = 0;
            loop {
                if i >= correlation_event_ids.len() {
                    break;
                }
                
                let event_id = *correlation_event_ids.at(i);
                let event = self.events.read(event_id);
                correlated_events.append(event);
                
                i += 1;
            };
            
            correlated_events
        }
    }
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _get_or_create_session(ref self: ContractState, user: ContractAddress) -> felt252 {
            let existing_session = self.user_sessions.read(user);
            if existing_session != 0 {
                existing_session
            } else {
                let session_counter = self.session_counter.read();
                let new_session_counter = session_counter + 1;
                self.session_counter.write(new_session_counter);
                let session_id = new_session_counter.into();
                self.user_sessions.write(user, session_id);
                session_id
            }
        }
        
        fn _update_user_events(ref self: ContractState, user: ContractAddress, event_id: felt252) {
            let mut user_events = self.user_events.read(user);
            user_events.append(event_id);
            self.user_events.write(user, user_events);
        }
        
        fn _update_category_events(ref self: ContractState, category: felt252, event_id: felt252) {
            let mut category_events = self.category_events.read(category);
            category_events.append(event_id);
            self.category_events.write(category, category_events);
        }
        
        fn _update_correlation_events(ref self: ContractState, correlation_id: felt252, event_id: felt252) {
            if correlation_id != 0 {
                let mut correlation_events = self.correlation_events.read(correlation_id);
                correlation_events.append(event_id);
                self.correlation_events.write(correlation_id, correlation_events);
            }
        }
    }
}