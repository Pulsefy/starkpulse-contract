use starknet::testing::{set_caller_address, set_contract_address, set_block_timestamp};
use starknet::ContractAddress;
use starknet::contract_address_const;

use starkpulse::utils::error_handling::{
    ErrorHandling, ErrorHandlingImpl, error_codes, VALIDATION_ERROR, SYSTEM_ERROR, EXECUTION_ERROR,
    ACCESS_ERROR, STATE_ERROR
};

// Mock contract for testing error handling
#[starknet::contract]
mod MockContract {
    use starkpulse::utils::error_handling::{ErrorHandling, ErrorHandlingImpl, error_codes};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl MockContractImpl {
        fn test_validation_error(ref self: ContractState) {
            self.emit_error(error_codes::INVALID_ADDRESS, 'Test validation error', 0);
        }

        fn test_system_error(ref self: ContractState) {
            self.emit_error(error_codes::CONTRACT_PAUSED, 'Test system error', 0);
        }

        fn test_execution_error(ref self: ContractState) {
            self.emit_error(error_codes::TRANSACTION_FAILED, 'Test execution error', 0);
        }
    }
}

#[test]
fn test_error_categories() {
    assert(ErrorHandlingImpl::get_error_category(1500) == VALIDATION_ERROR, 'Wrong validation category');
    assert(ErrorHandlingImpl::get_error_category(2500) == SYSTEM_ERROR, 'Wrong system category');
    assert(ErrorHandlingImpl::get_error_category(3500) == EXECUTION_ERROR, 'Wrong execution category');
    assert(ErrorHandlingImpl::get_error_category(4500) == ACCESS_ERROR, 'Wrong access category');
    assert(ErrorHandlingImpl::get_error_category(5500) == STATE_ERROR, 'Wrong state category');
}

#[test]
fn test_error_messages() {
    assert(
        ErrorHandlingImpl::get_error_message(error_codes::INVALID_ADDRESS) == 'Invalid address provided',
        'Wrong invalid address message'
    );
    assert(
        ErrorHandlingImpl::get_error_message(error_codes::INSUFFICIENT_BALANCE) == 'Insufficient balance for operation',
        'Wrong insufficient balance message'
    );
    assert(
        ErrorHandlingImpl::get_error_message(error_codes::UNAUTHORIZED_ACCESS) == 'Unauthorized access attempt',
        'Wrong unauthorized access message'
    );
    assert(
        ErrorHandlingImpl::get_error_message(9999) == 'Unknown error occurred',
        'Wrong unknown error message'
    );
}

#[test]
fn test_error_event_emission() {
    // Set up test environment
    let contract_address = contract_address_const::<1>();
    set_caller_address(contract_address);
    set_contract_address(contract_address);

    // Deploy mock contract
    let mock_contract = MockContract::deploy().unwrap();

    // Test validation error
    mock_contract.test_validation_error();
    // Event assertion would go here once available in StarkNet testing framework

    // Test system error
    mock_contract.test_system_error();
    // Event assertion would go here

    // Test execution error
    mock_contract.test_execution_error();
    // Event assertion would go here
}

#[test]
fn test_error_additional_data() {
    let contract_address = contract_address_const::<1>();
    set_caller_address(contract_address);
    set_contract_address(contract_address);

    // Test error with additional data
    let mock_contract = MockContract::deploy().unwrap();
    mock_contract.test_validation_error();
    // Verify additional data in event once available
}
