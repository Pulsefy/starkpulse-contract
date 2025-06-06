#[starknet::contract]
mod ContractInteraction {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::Map;
    use zeroable::Zeroable;

    use openzeppelin::security::PausableComponent;

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);

    // Pausable
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    
    #[storage]
    struct Storage {
        // Contract registry
        registered_contracts: Map<felt252, ContractAddress>,
        // Caller approvals
        approved_callers: Map<(felt252, ContractAddress), bool>,
        // Admin address
        admin: ContractAddress,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContractRegistered: ContractRegistered,
        CallerApproved: CallerApproved,
        CallerRevoked: CallerRevoked,
        ContractCalled: ContractCalled,
        #[flat]
        PausableEvent: PausableComponent::Event,
    }
    
    #[derive(Drop, starknet::Event)]
    struct ContractRegistered {
        contract_name: felt252,
        contract_address: ContractAddress
    }
    
    #[derive(Drop, starknet::Event)]
    struct CallerApproved {
        contract_name: felt252,
        caller_address: ContractAddress
    }
    
    #[derive(Drop, starknet::Event)]
    struct CallerRevoked {
        contract_name: felt252,
        caller_address: ContractAddress
    }
    
    #[derive(Drop, starknet::Event)]
    struct ContractCalled {
        contract_name: felt252,
        function_name: felt252,
        caller: ContractAddress
    }
    
    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        assert(!admin_address.is_zero(), "Invalid admin address");
        self.admin.write(admin_address);
    }
    
    #[abi(embed_v0)]
    impl ContractInteractionImpl of super::IContractInteraction<ContractState> {
        fn register_contract(
            ref self: ContractState,
            contract_name: felt252,
            contract_address: ContractAddress
        ) -> bool {
            self.assert_only_admin();
            assert(!contract_address.is_zero(), "Invalid contract address");
            
            // Check if contract already registered
            let existing_address = self.registered_contracts.read(contract_name);
            assert(existing_address.is_zero(), "Contract already registered");
            
            self.registered_contracts.write(contract_name, contract_address);
            
            self.emit(ContractRegistered {
                contract_name: contract_name,
                contract_address: contract_address
            });
            
            true
        }
        
        fn approve_caller(
            ref self: ContractState,
            contract_name: felt252,
            caller_address: ContractAddress
        ) -> bool {
            self.assert_only_admin();
            assert(!caller_address.is_zero(), "Invalid caller address");
            
            // Verify contract exists
            let contract_address = self.registered_contracts.read(contract_name);
            assert(!contract_address.is_zero(), "Contract not registered");
            
            self.approved_callers.write((contract_name, caller_address), true);
            
            self.emit(CallerApproved {
                contract_name: contract_name,
                caller_address: caller_address
            });
            
            true
        }
        
        fn revoke_caller(
            ref self: ContractState,
            contract_name: felt252,
            caller_address: ContractAddress
        ) -> bool {
            self.assert_only_admin();
            assert(!caller_address.is_zero(), "Invalid caller address");
            
            self.approved_callers.write((contract_name, caller_address), false);
            
            self.emit(CallerRevoked {
                contract_name: contract_name,
                caller_address: caller_address
            });
            
            true
        }
        
        fn get_contract_address(
            self: @ContractState,
            contract_name: felt252
        ) -> ContractAddress {
            let address = self.registered_contracts.read(contract_name);
            assert(!address.is_zero(), "Contract not registered");
            address
        }
        
        fn call_contract(
            ref self: ContractState,
            contract_name: felt252,
            function_name: felt252,
            calldata: Array<felt252>
        ) -> Array<felt252> {
            let caller = get_caller_address();
            
            // Verify caller is approved
            let is_approved = self.approved_callers.read((contract_name, caller));
            assert(is_approved, "Caller not approved");
            
            // Get contract address
            let contract_address = self.registered_contracts.read(contract_name);
            assert(!contract_address.is_zero(), "Contract not registered");
            
            // Execute the call
            let mut result = ArrayTrait::new();
            let success = starknet::call_contract_syscall(
                contract_address,
                function_name,
                calldata.span(),
                result.span()
            );
            
            assert(success == 0, "Contract call failed");
            
            self.emit(ContractCalled {
                contract_name: contract_name,
                function_name: function_name,
                caller: caller
            });
            
            result
        }
        // Pause the contract
        fn pause(ref self: ContractState) {
            self.assert_only_admin();
            self.pausable.pause();
        }
        // Unpause the contract
        fn unpause(ref self: ContractState) {
            self.assert_only_admin();
            self.pausable.unpause();
        }
    }
    
    #[generate_trait]
    impl HelperImpl of HelperTrait {
        fn assert_only_admin(ref self: ContractState) {
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(caller == admin, "Caller is not admin");
        }
    }
}