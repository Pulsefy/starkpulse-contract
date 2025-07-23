// Event Filtering Utility
#[starknet::contract]
mod EventFilter {
    use starknet::ContractAddress;
    use array::ArrayTrait;
    use crate::interfaces::i_event_system::{IEventSystem, IEventSystemDispatcher, StandardEvent};
    
    #[storage]
    struct Storage {
        event_system: IEventSystemDispatcher,
        filter_presets: Map<felt252, FilterPreset>,
    }
    
    #[derive(Drop, Serde, starknet::Store)]
    struct FilterPreset {
        name: felt252,
        categories: Array<felt252>,
        event_types: Array<felt252>,
        severity_min: u8,
        time_range: u64, // seconds
    }
    
    #[starknet::interface]
    trait IEventFilter<TContractState> {
        fn create_filter_preset(
            ref self: TContractState,
            name: felt252,
            categories: Array<felt252>,
            event_types: Array<felt252>,
            severity_min: u8,
            time_range: u64
        ) -> bool;
        
        fn apply_filter_preset(
            self: @TContractState,
            preset_name: felt252,
            user: ContractAddress
        ) -> Array<StandardEvent>;
        
        fn get_security_events(
            self: @TContractState,
            user: ContractAddress,
            severity_min: u8
        ) -> Array<StandardEvent>;
        
        fn get_transaction_events(
            self: @TContractState,
            user: ContractAddress,
            time_range: u64
        ) -> Array<StandardEvent>;
    }
}