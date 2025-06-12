#[starknet::interface]
trait ITransactionMonitor<TContractState> {
    // Transaction Recording
    fn record_transaction(
        ref self: TContractState, 
        tx_hash: felt252, 
        tx_type: felt252, 
        amount: u256,
        description: felt252
    ) -> bool;
    
    // Transaction Status Management
    fn update_transaction_status(
        ref self: TContractState,
        tx_hash: felt252,
        new_status: felt252
    ) -> bool;
    
    // Notification Preferences
    fn set_notification_preferences(
        ref self: TContractState,
        notification_types: Array<felt252>,
        enabled: bool
    ) -> bool;
    
    fn get_notification_preferences(
        self: @TContractState,
        user_address: starknet::ContractAddress
    ) -> Array<felt252>;
    
    // Transaction History
    fn get_transaction_history(
        self: @TContractState, 
        user_address: starknet::ContractAddress,
        page: u32,
        page_size: u32,
        filter_type: felt252,
        filter_status: felt252
    ) -> Array<Transaction>;
    
    // Transaction Details
    fn get_transaction_details(
        self: @TContractState,
        tx_hash: felt252
    ) -> Transaction;

    // Security Features
    fn verify_transaction_integrity(
        self: @TContractState,
        tx_hash: felt252,
        signature: Array<felt252>
    ) -> bool;

    fn create_transaction_proof(
        ref self: TContractState,
        tx_hash: felt252,
        proof_data: Array<felt252>
    ) -> felt252;

    fn verify_transaction_proof(
        self: @TContractState,
        tx_hash: felt252,
        proof_hash: felt252
    ) -> bool;

    fn get_transaction_audit_trail(
        self: @TContractState,
        tx_hash: felt252
    ) -> Array<felt252>;

    fn flag_suspicious_transaction(
        ref self: TContractState,
        tx_hash: felt252,
        reason: felt252
    ) -> bool;
}

#[derive(Drop, Serde, starknet::Store)]
struct Transaction {
    tx_hash: felt252,
    user: starknet::ContractAddress,
    tx_type: felt252,
    amount: u256,
    timestamp: u64,
    status: felt252,
    description: felt252,
    // Security fields
    integrity_hash: felt252,
    proof_hash: felt252,
    verified: bool,
    flagged: bool,
    risk_score: u256,
}

#[derive(Drop, Serde, starknet::Store)]
struct TransactionMonitorTypes {
    TransactionRecorded: Event,
    TransactionStatusUpdated: Event,
    NotificationPreferencesSet: Event,
}