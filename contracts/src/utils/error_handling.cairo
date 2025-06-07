use starknet::ContractAddress;

// Error Categories
const VALIDATION_ERROR: felt252 = 1;
const SYSTEM_ERROR: felt252 = 2;
const EXECUTION_ERROR: felt252 = 3;
const ACCESS_ERROR: felt252 = 4;
const STATE_ERROR: felt252 = 5;

#[derive(Drop, starknet::Event)]
struct ErrorOccurred {
    error_code: felt252,
    error_category: felt252,
    message: felt252,
    contract_address: ContractAddress,
    additional_data: felt252
}

trait ErrorHandling {
    fn emit_error(self: @ContractState, error_code: felt252, message: felt252, additional_data: felt252);
    fn get_error_message(error_code: felt252) -> felt252;
    fn get_error_category(error_code: felt252) -> felt252;
}

// Error Code Constants
mod error_codes {
    const INVALID_ADDRESS: felt252 = 1001;
    const INSUFFICIENT_BALANCE: felt252 = 1002;
    const UNAUTHORIZED_ACCESS: felt252 = 1003;
    const INVALID_AMOUNT: felt252 = 1004;
    const CONTRACT_PAUSED: felt252 = 1005;
    const INVALID_OPERATION: felt252 = 1006;
    const TRANSACTION_FAILED: felt252 = 1007;
    const STATE_INVALID: felt252 = 1008;
    const ZERO_VALUE: felt252 = 1009;
    const OVERFLOW: felt252 = 1010;
}

// Implementation of error handling
impl ErrorHandlingImpl of ErrorHandling {
    fn emit_error(self: @ContractState, error_code: felt252, message: felt252, additional_data: felt252) {
        // Get the contract address
        let contract_address = starknet::get_contract_address();
        
        // Emit the error event
        self.emit(ErrorOccurred {
            error_code,
            error_category: self.get_error_category(error_code),
            message,
            contract_address,
            additional_data
        });
    }

    fn get_error_message(error_code: felt252) -> felt252 {
        match error_code {
            error_codes::INVALID_ADDRESS => 'Invalid address provided',
            error_codes::INSUFFICIENT_BALANCE => 'Insufficient balance for operation',
            error_codes::UNAUTHORIZED_ACCESS => 'Unauthorized access attempt',
            error_codes::INVALID_AMOUNT => 'Invalid amount specified',
            error_codes::CONTRACT_PAUSED => 'Contract is currently paused',
            error_codes::INVALID_OPERATION => 'Invalid operation attempted',
            error_codes::TRANSACTION_FAILED => 'Transaction execution failed',
            error_codes::STATE_INVALID => 'Invalid contract state',
            error_codes::ZERO_VALUE => 'Zero value not allowed',
            error_codes::OVERFLOW => 'Arithmetic overflow occurred',
            _ => 'Unknown error occurred'
        }
    }

    fn get_error_category(error_code: felt252) -> felt252 {
        if error_code >= 1000 && error_code < 2000 {
            VALIDATION_ERROR
        } else if error_code >= 2000 && error_code < 3000 {
            SYSTEM_ERROR
        } else if error_code >= 3000 && error_code < 4000 {
            EXECUTION_ERROR
        } else if error_code >= 4000 && error_code < 5000 {
            ACCESS_ERROR
        } else {
            STATE_ERROR
        }
    }
}
