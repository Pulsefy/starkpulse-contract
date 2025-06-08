use starknet::ContractAddress;

#[starknet::interface]
trait IErrorHandling {
    fn emit_error(error_code: felt252, message: felt252, additional_data: felt252);
    fn get_error_message(error_code: felt252) -> felt252;
    fn get_error_category(error_code: felt252) -> felt252;
}

// Error code ranges documentation
// 1000-1999: Validation Errors (input validation, parameter checks)
// 2000-2999: System Errors (contract state, system limitations)
// 3000-3999: Execution Errors (runtime errors, arithmetic errors)
// 4000-4999: Access Control Errors (permissions, authorization)
// 5000-5999: State Errors (invalid state transitions)

// Standard error messages for common scenarios
const ERROR_INVALID_CALLER: felt252 = 'Caller is not authorized';
const ERROR_ZERO_ADDRESS: felt252 = 'Zero address provided';
const ERROR_ZERO_AMOUNT: felt252 = 'Amount cannot be zero';
const ERROR_INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
const ERROR_INVALID_STATE: felt252 = 'Invalid contract state';
const ERROR_OVERFLOW: felt252 = 'Arithmetic overflow';
const ERROR_CONTRACT_PAUSED: felt252 = 'Contract is paused';
