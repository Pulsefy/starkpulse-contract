// StarkPulse Standardized Event System Interface
use starknet::ContractAddress;
use array::ArrayTrait;

// Event versioning constants
const EVENT_VERSION_1_0: felt252 = 'v1.0';
const EVENT_VERSION_1_1: felt252 = 'v1.1';
const EVENT_VERSION_CURRENT: felt252 = EVENT_VERSION_1_0;

// Event categories for filtering
const CATEGORY_TRANSACTION: felt252 = 'TRANSACTION';
const CATEGORY_SECURITY: felt252 = 'SECURITY';
const CATEGORY_PORTFOLIO: felt252 = 'PORTFOLIO';
const CATEGORY_GOVERNANCE: felt252 = 'GOVERNANCE';
const CATEGORY_SYSTEM: felt252 = 'SYSTEM';
const CATEGORY_USER: felt252 = 'USER';
const CATEGORY_ANALYTICS: felt252 = 'ANALYTICS';

// Event severity levels
const SEVERITY_INFO: u8 = 1;
const SEVERITY_WARNING: u8 = 2;
const SEVERITY_ERROR: u8 = 3;
const SEVERITY_CRITICAL: u8 = 4;

#[derive(Drop, Serde, starknet::Store)]
struct StandardEventMetadata {
    version: felt252,
    category: felt252,
    severity: u8,
    contract_address: ContractAddress,
    block_number: u64,
    timestamp: u64,
    correlation_id: felt252, // For linking related events
    session_id: felt252,     // For user session tracking
}

#[derive(Drop, Serde, starknet::Store)]
struct StandardEvent {
    #[key]
    event_id: felt252,
    #[key]
    event_type: felt252,
    #[key]
    user: ContractAddress,
    metadata: StandardEventMetadata,
    data: Array<felt252>,
    indexed_data: Array<felt252>, // For efficient filtering
}

#[starknet::interface]
trait IEventSystem<TContractState> {
    fn emit_standard_event(
        ref self: TContractState,
        event_type: felt252,
        category: felt252,
        severity: u8,
        user: ContractAddress,
        data: Array<felt252>,
        indexed_data: Array<felt252>,
        correlation_id: felt252
    ) -> felt252;
    
    fn get_events_by_filter(
        self: @TContractState,
        category: felt252,
        event_type: felt252,
        user: ContractAddress,
        start_time: u64,
        end_time: u64,
        version: felt252
    ) -> Array<StandardEvent>;
    
    fn get_events_by_correlation(
        self: @TContractState,
        correlation_id: felt252
    ) -> Array<StandardEvent>;
}