#[starknet::interface]
trait IContractInteraction<TContractState> {
    // Contract Registration
    fn register_contract(
        ref self: TContractState,
        contract_name: felt252,
        contract_address: starknet::ContractAddress
    ) -> bool;
    
    // Caller Approval Management
    fn approve_caller(
        ref self: TContractState,
        contract_name: felt252,
        caller_address: starknet::ContractAddress
    ) -> bool;
    
    fn revoke_caller(
        ref self: TContractState,
        contract_name: felt252,
        caller_address: starknet::ContractAddress
    ) -> bool;
    
    // Contract Address Retrieval
    fn get_contract_address(
        self: @TContractState,
        contract_name: felt252
    ) -> starknet::ContractAddress;
    
    // Secure Contract Interaction
    fn call_contract(
        ref self: TContractState,
        contract_name: felt252,
        function_name: felt252,
        calldata: Array<felt252>
    ) -> Array<felt252>;

    // Batch contract calls
    fn batch_call_contracts(
        ref self: TContractState,
        calls: Array<BatchCallDescriptor>,
        use_cache: bool,
        retry_count: u8
    ) -> Array<BatchCallResult>;
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ContractInteractionTypes {
    ContractRegistered: Event,
    CallerApproved: Event,
    CallerRevoked: Event,
    ContractCalled: Event
}

#[derive(Drop, Serde, starknet::Store)]
struct BatchCallDescriptor {
    contract_name: felt252,
    function_name: felt252,
    calldata: Array<felt252>,
}

#[derive(Drop, Serde, starknet::Store)]
struct BatchCallResult {
    success: bool,
    return_data: Array<felt252>,
    error_message: felt252,
}