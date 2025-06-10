#[cfg(test)]
mod test_contract_interaction {
    use starknet::{ContractAddress, contract_address_const, get_caller_address};
    use starknet::testing::set_caller_address;
    
    use crate::utils::contract_interaction::ContractInteraction;
    use crate::interfaces::i_contract_interaction::IContractInteraction;
    
    // Test addresses
    const ADMIN: felt252 = 0x123;
    const USER1: felt252 = 0x456;
    const CONTRACT1: felt252 = 0x789;
    const CONTRACT_NAME: felt252 = 'TEST_CONTRACT';
    
    #[test]
    #[available_gas(2000000)]
    fn test_contract_registration() {
        let admin = contract_address_const::<ADMIN>();
        let contract_address = contract_address_const::<CONTRACT1>();
        
        set_caller_address(admin);
        
        let mut contract = ContractInteraction::unsafe_new();
        contract.register_contract(CONTRACT_NAME, contract_address);
        
        let retrieved_address = contract.get_contract_address(CONTRACT_NAME);
        assert(retrieved_address == contract_address, "Address mismatch");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_caller_approval() {
        let admin = contract_address_const::<ADMIN>();
        let user1 = contract_address_const::<USER1>();
        let contract_address = contract_address_const::<CONTRACT1>();
        
        set_caller_address(admin);
        
        let mut contract = ContractInteraction::unsafe_new();
        contract.register_contract(CONTRACT_NAME, contract_address);
        contract.approve_caller(CONTRACT_NAME, user1);
        
        // Test calling contract (simulated)
        set_caller_address(user1);
        // Would normally call contract here
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_contract_calling() {
        let admin = contract_address_const::<ADMIN>();
        let user1 = contract_address_const::<USER1>();
        let contract_address = contract_address_const::<CONTRACT1>();
        
        set_caller_address(admin);
        
        let mut contract = ContractInteraction::unsafe_new();
        contract.register_contract(CONTRACT_NAME, contract_address);
        contract.approve_caller(CONTRACT_NAME, user1);
        
        set_caller_address(user1);
        
        // This would fail if caller wasn't approved
        let _ = contract.call_contract(CONTRACT_NAME, 'test_function', array![]);
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_batch_call_contracts() {
        let admin = contract_address_const::<ADMIN>();
        let user1 = contract_address_const::<USER1>();
        let contract_address = contract_address_const::<CONTRACT1>();
        set_caller_address(admin);
        let mut contract = ContractInteraction::unsafe_new();
        contract.register_contract(CONTRACT_NAME, contract_address);
        contract.approve_caller(CONTRACT_NAME, user1);
        set_caller_address(user1);
        let call1 = BatchCallDescriptor {
            contract_name: CONTRACT_NAME,
            function_name: 'test_function',
            calldata: array![],
        };
        let call2 = BatchCallDescriptor {
            contract_name: CONTRACT_NAME,
            function_name: 'test_function',
            calldata: array![1, 2, 3],
        };
        let calls = array![call1, call2];
        let results = contract.batch_call_contracts(calls, false, 0);
        assert(results.len() == 2, 'Batch should return two results');
        assert(results.at(0).success, 'First call should succeed');
        assert(results.at(1).success, 'Second call should succeed');
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_batch_call_contracts_with_cache() {
        let admin = contract_address_const::<ADMIN>();
        let user1 = contract_address_const::<USER1>();
        let contract_address = contract_address_const::<CONTRACT1>();
        set_caller_address(admin);
        let mut contract = ContractInteraction::unsafe_new();
        contract.register_contract(CONTRACT_NAME, contract_address);
        contract.approve_caller(CONTRACT_NAME, user1);
        set_caller_address(user1);
        let call = BatchCallDescriptor {
            contract_name: CONTRACT_NAME,
            function_name: 'test_function',
            calldata: array![42],
        };
        let calls = array![call];
        // First call, not cached
        let results1 = contract.batch_call_contracts(calls.clone(), true, 0);
        assert(results1.at(0).success, 'First call should succeed');
        // Second call, should hit cache
        let results2 = contract.batch_call_contracts(calls, true, 0);
        assert(results2.at(0).success, 'Second call should succeed (from cache)');
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_batch_call_contracts_with_retry() {
        let admin = contract_address_const::<ADMIN>();
        let user1 = contract_address_const::<USER1>();
        let contract_address = contract_address_const::<CONTRACT1>();
        set_caller_address(admin);
        let mut contract = ContractInteraction::unsafe_new();
        contract.register_contract(CONTRACT_NAME, contract_address);
        contract.approve_caller(CONTRACT_NAME, user1);
        set_caller_address(user1);
        let call = BatchCallDescriptor {
            contract_name: CONTRACT_NAME,
            function_name: 'test_function',
            calldata: array![99],
        };
        let calls = array![call];
        // Retry count set to 2 (should succeed on first try in this stub)
        let results = contract.batch_call_contracts(calls, false, 2);
        assert(results.at(0).success, 'Call should succeed with retry logic');
    }
}