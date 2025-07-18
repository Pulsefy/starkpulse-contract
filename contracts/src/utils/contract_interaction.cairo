#[starknet::contract]
mod ContractInteraction {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::Map;
    use zeroable::Zeroable;
    use contracts::src::interfaces::i_contract_interaction::{BatchCallDescriptor, BatchCallResult};
    use starknet::pedersen_hash_array;
    
    #[storage]
    struct Storage {
        // Contract registry
        registered_contracts: Map<felt252, ContractAddress>,
        // Caller approvals
        approved_callers: Map<(felt252, ContractAddress), bool>,
        // Admin address
        admin: ContractAddress,
        // Caching for call results
        cached_results: Map<(felt252, felt252, felt252), Array<felt252>>,
        // Rate limiting: per-user (address → [count, last_timestamp])
        user_rate: Map<ContractAddress, (u64, u64)>,
        // Global rate limiting: [count, last_timestamp]
        global_rate_count: u64,
        global_rate_last_timestamp: u64,
        // Adaptive rate limiting: stores current global threshold
        adaptive_global_limit: u64,
        // Trusted user bypass (uses AccessControl roles, but can cache here if needed)
    }

    // Rate limiting role constant
    const TRUSTED_USER_ROLE: felt252 = 'TRUSTED_USER_ROLE';

    // Rate limiting events
    #[derive(Drop, starknet::Event)]
    struct RateLimitHit {
        user: ContractAddress,
        is_global: bool,
        current_count: u64,
        limit: u64,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    struct RateLimitBypass {
        user: ContractAddress,
        reason: felt252,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    struct RateLimitAdjusted {
        new_limit: u64,
        reason: felt252,
        timestamp: u64,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContractRegistered: ContractRegistered,
        CallerApproved: CallerApproved,
        CallerRevoked: CallerRevoked,
        ContractCalled: ContractCalled
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
    
    // Utility: tightly pack calldata for contract calls
    fn pack_calldata(params: Array<felt252>) -> Array<felt252> {
        // In a real implementation, this would remove unnecessary zero-padding and pack values efficiently.
        // For demonstration, we remove trailing zeros (common Cairo inefficiency) and return the packed array.
        let mut packed = ArrayTrait::new();
        let len = params.len();
        let mut last_nonzero = 0;
        let mut i = 0;
        while i < len {
            if params.at(i) != 0 {
                last_nonzero = i;
            }
            i += 1;
        }
        // Copy up to last nonzero
        i = 0;
        while i <= last_nonzero {
            packed.append(params.at(i));
            i += 1;
        }
        packed
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
            // Rate limiting check
            assert(self.check_rate_limits(caller), "Rate limit exceeded");
            
            // Verify caller is approved
            let is_approved = self.approved_callers.read((contract_name, caller));
            assert(is_approved, "Caller not approved");
            
            // Get contract address
            let contract_address = self.registered_contracts.read(contract_name);
            assert(!contract_address.is_zero(), "Contract not registered");
            
            // --- Calldata packing optimization ---
            let packed_calldata = Self::pack_calldata(calldata);
            // Execute the call
            let mut result = ArrayTrait::new();
            let success = starknet::call_contract_syscall(
                contract_address,
                function_name,
                packed_calldata.span(),
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
        
        fn batch_call_contracts(
            ref self: ContractState,
            calls: Array<BatchCallDescriptor>,
            use_cache: bool,
            retry_count: u8
        ) -> Array<BatchCallResult> {
            let caller = get_caller_address();
            // Rate limiting check (batch counts as one interaction)
            assert(self.check_rate_limits(caller), "Rate limit exceeded");
            
            let mut results = ArrayTrait::new();
            let len = calls.len();
            let mut i = 0;
            while i < len {
                let call = calls.at(i);
                let calldata_hash = starknet::pedersen_hash_array(call.calldata.clone());
                let mut result: Array<felt252> = ArrayTrait::new();
                let mut success = true;
                let mut error_message: felt252 = 0;
                // Caching logic
                if use_cache {
                    let cached = self.cached_results.read((call.contract_name, call.function_name, calldata_hash));
                    if cached.len() > 0 {
                        results.append(BatchCallResult {
                            success: true,
                            return_data: cached,
                            error_message: 0,
                        });
                        i += 1;
                        continue;
                    }
                }
                // Retry logic
                let mut attempt = 0;
                while attempt <= retry_count {
                    let call_result = self.call_contract(
                        call.contract_name,
                        call.function_name,
                        call.calldata.clone()
                    );
                    // If call_contract panics, catch and set success = false (pseudo, Cairo 1.0+ needed for real try/catch)
                    // For now, assume success if no panic
                    result = call_result;
                    success = true;
                    error_message = 0;
                    break;
                    attempt += 1;
                }
                if use_cache && success {
                    self.cached_results.write((call.contract_name, call.function_name, calldata_hash), result.clone());
                }
                results.append(BatchCallResult {
                    success: success,
                    return_data: result,
                    error_message: error_message,
                });
                i += 1;
            }
            results
        }
        
        fn check_rate_limits(ref self: ContractState, caller: ContractAddress) -> bool {
            // Trusted user bypass
            let access_control_address = self.admin.read(); // For demo, assume admin is access control contract
            let is_trusted = contracts::src::utils::access_control::AccessControl::has_role(
                access_control_address, TRUSTED_USER_ROLE, caller
            );
            let now = get_block_timestamp();
            if is_trusted {
                self.emit(RateLimitBypass {
                    user: caller,
                    reason: 'trusted_user',
                    timestamp: now,
                });
                return true;
            }
            // Per-user rate limiting
            let (user_count, user_last) = self.user_rate.read(caller);
            let user_limit = 10; // Example static limit
            if user_last == now {
                if user_count >= user_limit {
                    self.emit(RateLimitHit {
                        user: caller,
                        is_global: false,
                        current_count: user_count,
                        limit: user_limit,
                        timestamp: now,
                    });
                    return false;
                }
                self.user_rate.write(caller, (user_count + 1, now));
            } else {
                self.user_rate.write(caller, (1, now));
            }
            // Global rate limiting
            let global_last = self.global_rate_last_timestamp.read();
            let global_count = self.global_rate_count.read();
            let global_limit = self.adaptive_global_limit.read();
            if global_last == now {
                if global_count >= global_limit {
                    self.emit(RateLimitHit {
                        user: caller,
                        is_global: true,
                        current_count: global_count,
                        limit: global_limit,
                        timestamp: now,
                    });
                    return false;
                }
                self.global_rate_count.write(global_count + 1);
            } else {
                self.global_rate_count.write(1);
                self.global_rate_last_timestamp.write(now);
            }
            return true;
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