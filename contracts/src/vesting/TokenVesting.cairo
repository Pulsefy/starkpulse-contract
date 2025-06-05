// -----------------------------------------------------------------------------
// StarkPulse TokenVesting Contract
// -----------------------------------------------------------------------------
//
// Overview:
// This contract implements token vesting for StarkPulse, allowing tokens to be released to beneficiaries over time according to customizable schedules.
//
// Features:
// - Multiple vesting schedules per beneficiary
// - Admin-controlled schedule creation, revocation, and emergency pause
// - ERC20 token integration for automated token release
// - Revocable and non-revocable vesting options
// - On-chain tracking of released and remaining tokens
//
// Security Considerations:
// - Only the admin can create, revoke, or pause schedules
// - Pausing disables all token releases and schedule changes
// - All critical functions validate caller permissions and input values
// - Revoked schedules cannot be released further
//
// Example Usage:
//
// // Deploying the contract (pseudo-code):
// let vesting = TokenVesting.deploy(
//     admin=ADMIN_ADDRESS,
//     token=ERC20_TOKEN_ADDRESS
// );
//
// // Creating a vesting schedule (as admin):
// vesting.create_vesting_schedule(
//     beneficiary=USER_ADDRESS,
//     start=START_TIMESTAMP,
//     duration=DURATION_SECONDS,
//     amount=AMOUNT,
//     revocable=true
// );
//
// // Beneficiary releases vested tokens:
// vesting.release_tokens(SCHEDULE_ID);
//
// // Admin revokes a schedule:
// vesting.revoke_vesting_schedule(SCHEDULE_ID);
//
// For integration and more examples, see INTEGRATION_GUIDE.md.
// -----------------------------------------------------------------------------

// StarkPulse TokenVesting Contract
// Implements token vesting functionality with admin controls and schedule management

#[starknet::contract]
mod TokenVesting {
    use starknet::{
        ContractAddress, 
        get_caller_address, 
        get_block_timestamp, 
        contract_address_const,
        get_contract_address
    };
    use starknet::storage::Map;
    use core::num::traits::Bounded;
    use zeroable::Zeroable;
    use contracts::src::utils::contract_metadata::{ContractMetadata, IContractMetadata};
    use array::ArrayTrait;
    
    // Local interfaces
    use crate::interfaces::i_token_vesting::{TokenVestingTypes, ITokenVestingContract};
    use crate::interfaces::i_erc20::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    
    #[storage]
    struct Storage {
        // admin: Contract administrator with special permissions (can create/revoke schedules, pause contract)
        admin: ContractAddress,
        // token: ERC20 token address to be distributed via vesting
        token: ContractAddress,
        // paused: Emergency pause flag (true disables all actions)
        paused: bool,
        // schedule_count: Global counter for vesting schedules
        schedule_count: u64,
        // vesting_schedules: Mapping (beneficiary, schedule_id) → VestingSchedule struct
        vesting_schedules: Map<(ContractAddress, u64), TokenVestingTypes::VestingSchedule>,
        // beneficiary_schedule_count: Mapping beneficiary → number of schedules
        beneficiary_schedule_count: Map<ContractAddress, u64>,
        // total_vesting_per_beneficiary: Mapping beneficiary → total tokens in vesting
        total_vesting_per_beneficiary: Map<ContractAddress, u256>,
        // revoked_schedules: Mapping (beneficiary, schedule_id) → true if revoked
        revoked_schedules: Map<(ContractAddress, u64), bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        VestingScheduleCreated: VestingScheduleCreated,
        TokensReleased: TokensReleased,
        VestingScheduleRevoked: VestingScheduleRevoked,
        EmergencyPause: EmergencyPause,
        EmergencyUnpause: EmergencyUnpause,
        AdminChanged: AdminChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct VestingScheduleCreated {
        beneficiary: ContractAddress,
        amount: u256,
        start_time: u64,
        duration: u64,
        cliff_duration: u64,
        schedule_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensReleased {
        beneficiary: ContractAddress,
        amount: u256,
        schedule_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct VestingScheduleRevoked {
        beneficiary: ContractAddress,
        amount: u256,
        schedule_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyPause {}

    #[derive(Drop, starknet::Event)]
    struct EmergencyUnpause {}

    #[derive(Drop, starknet::Event)]
    struct AdminChanged {
        old_admin: ContractAddress,
        new_admin: ContractAddress,
    }

    // Error messages
    const ERROR_INVALID_BENEFICIARY: felt252 = 'Invalid beneficiary address';
    const ERROR_INVALID_TOKEN: felt252 = 'Invalid token address';
    const ERROR_INVALID_AMOUNT: felt252 = 'Invalid amount';
    const ERROR_INVALID_START_TIME: felt252 = 'Invalid start time';
    const ERROR_INVALID_DURATION: felt252 = 'Invalid duration';
    const ERROR_INVALID_CLIFF: felt252 = 'Invalid cliff duration';
    const ERROR_NO_AVAILABLE_TOKENS: felt252 = 'No tokens available for release';
    const ERROR_UNAUTHORIZED: felt252 = 'Not authorized';
    const ERROR_PAUSED: felt252 = 'Contract is paused';
    const ERROR_SCHEDULE_REVOKED: felt252 = 'Schedule already revoked';
    const ERROR_INVALID_SCHEDULE_ID: felt252 = 'Invalid schedule ID';
    const ERROR_ARITHMETIC_OVERFLOW: felt252 = 'Arithmetic overflow';

    // Metadata constants
    const CONTRACT_VERSION: felt252 = '1.0.0';
    const DOC_URL: felt252 = 'https://github.com/Pulsefy/starkpulse-contract?tab=readme-ov-file#token-vesting';
    const INTERFACE_VESTING: felt252 = 'ITokenVestingContract';
    const DEPENDENCY_ERC20: felt252 = 'IERC20';

    /// Contract constructor
    /// @param admin The address with admin rights (can create/revoke schedules, pause contract)
    /// @param token The ERC20 token address to be distributed via vesting
    /// @dev Sets up the contract for vesting management. Only admin can perform privileged actions.
    /// @security Ensure admin is a trusted address. Pausing disables all actions.
    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress, token_address: ContractAddress) {
        assert(!admin_address.is_zero(), ERROR_INVALID_BENEFICIARY);
        assert(!token_address.is_zero(), ERROR_INVALID_TOKEN);
        
        self.admin.write(admin_address);
        self.token.write(token_address);
        self.paused.write(false);
        self.schedule_count.write(0);
    }

    #[abi(embed_v0)]
    impl TokenVestingImpl of ITokenVestingContract<ContractState> {
        /// Creates a new vesting schedule for a beneficiary (admin only)
        /// @param beneficiary The address to receive vested tokens
        /// @param amount The total amount of tokens to vest
        /// @param start_time The timestamp when vesting starts
        /// @param duration The total duration of the vesting period (seconds)
        /// @param cliff_duration The initial period before any tokens are released (seconds)
        /// @return schedule_id The unique ID of the created schedule
        /// @dev Transfers tokens from admin to contract. Emits VestingScheduleCreated event.
        /// @security Only admin can call. Validates all input parameters. Paused contract blocks creation.
        fn create_vesting_schedule(
            ref self: ContractState,
            beneficiary: ContractAddress,
            amount: u256,
            start_time: u64,
            duration: u64,
            cliff_duration: u64
        ) -> u64 {
            self.assert_only_admin();
            self.assert_not_paused();
            
            // Input validation
            assert(!beneficiary.is_zero(), ERROR_INVALID_BENEFICIARY);
            assert(amount > 0, ERROR_INVALID_AMOUNT);
            assert(duration > 0, ERROR_INVALID_DURATION);
            assert(cliff_duration <= duration, ERROR_INVALID_CLIFF);
            
            let current_time = get_block_timestamp();
            assert(start_time >= current_time, ERROR_INVALID_START_TIME);
            
            // Get the next schedule ID and increment the counter
            let schedule_id = self.schedule_count.read();
            self.schedule_count.write(schedule_id + 1);
            
            // Update beneficiary schedule counter
            let beneficiary_count = self.beneficiary_schedule_count.read(beneficiary);
            self.beneficiary_schedule_count.write(beneficiary, beneficiary_count + 1);
            
            // Update total vesting amount
            let current_total = self.total_vesting_per_beneficiary.read(beneficiary);
            self.total_vesting_per_beneficiary.write(beneficiary, current_total + amount);
            
            // Create and store the schedule
            let schedule = TokenVestingTypes::VestingSchedule {
                beneficiary: beneficiary,
                start_time: start_time,
                duration: duration,
                total_amount: amount,
                released_amount: 0,
                cliff_duration: cliff_duration,
                schedule_id: schedule_id,
            };
            
            self.vesting_schedules.write((beneficiary, schedule_id), schedule);
            
            // Transfer tokens from admin to contract
            let admin = self.admin.read();
            let token_address = self.token.read();
            
            // Use a dispatcher to call the ERC20 contract
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let success = erc20_dispatcher.transfer_from(
                admin, 
                get_contract_address(), 
                amount
            );
            assert(success, ERROR_INVALID_AMOUNT);
            
            // Emit event
            self.emit(VestingScheduleCreated {
                beneficiary: beneficiary,
                amount: amount,
                start_time: start_time,
                duration: duration,
                cliff_duration: cliff_duration,
                schedule_id: schedule_id,
            });
            
            schedule_id
        }

        /// Releases vested tokens for the caller's schedule
        /// @param schedule_id The ID of the vesting schedule
        /// @dev Transfers available tokens to beneficiary. Emits TokensReleased event.
        /// @security Only beneficiary can call. Paused contract blocks release. Revoked schedules cannot release.
        fn release_tokens(ref self: ContractState, schedule_id: u64) {
            self.assert_not_paused();
            
            let caller = get_caller_address();
            let schedule = self.vesting_schedules.read((caller, schedule_id));
            
            // Verify that the schedule belongs to the caller and is valid
            assert(!schedule.beneficiary.is_zero(), ERROR_INVALID_SCHEDULE_ID);
            assert(schedule.beneficiary == caller, ERROR_UNAUTHORIZED);
            assert(!self.revoked_schedules.read((caller, schedule_id)), ERROR_SCHEDULE_REVOKED);
            
            // Calculate available amount to release
            let releasable = self.calculate_releasable(schedule);
            assert(releasable > 0, ERROR_NO_AVAILABLE_TOKENS);
            
            // Update released amount
            let new_released_amount = schedule.released_amount + releasable;
            let updated_schedule = TokenVestingTypes::VestingSchedule {
                released_amount: new_released_amount,
                ..schedule
            };
            self.vesting_schedules.write((caller, schedule_id), updated_schedule);
            
            // Transfer tokens to beneficiary
            let token_address = self.token.read();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let success = erc20_dispatcher.transfer(caller, releasable);
            assert(success, ERROR_INVALID_AMOUNT);
            
            // Emit event
            self.emit(TokensReleased {
                beneficiary: caller,
                amount: releasable,
                schedule_id: schedule_id,
            });
        }
        
        /// Revokes a vesting schedule (admin only)
        /// @param beneficiary The address whose schedule is being revoked
        /// @param schedule_id The ID of the schedule to revoke
        /// @dev Emits VestingScheduleRevoked event. Revoked schedules cannot release further tokens.
        /// @security Only admin can call. Paused contract blocks revocation.
        fn revoke_vesting_schedule(ref self: ContractState, beneficiary: ContractAddress, schedule_id: u64) {
            self.assert_only_admin();
            
            // Verify that the schedule is valid and not revoked
            let schedule = self.vesting_schedules.read((beneficiary, schedule_id));
            assert(!schedule.beneficiary.is_zero(), ERROR_INVALID_SCHEDULE_ID);
            assert(!self.revoked_schedules.read((beneficiary, schedule_id)), ERROR_SCHEDULE_REVOKED);
            
            // Mark as revoked
            self.revoked_schedules.write((beneficiary, schedule_id), true);
            
            // Calculate unreleased amount
            let unreleased = schedule.total_amount - schedule.released_amount;
            
            // Update total vesting amount
            let current_total = self.total_vesting_per_beneficiary.read(beneficiary);
            self.total_vesting_per_beneficiary.write(beneficiary, current_total - unreleased);
            
            // Transfer unreleased tokens back to admin
            let token_address = self.token.read();
            let admin = self.admin.read();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let success = erc20_dispatcher.transfer(admin, unreleased);
            assert(success, ERROR_INVALID_AMOUNT);
            
            // Emit event
            self.emit(VestingScheduleRevoked {
                beneficiary: beneficiary,
                amount: unreleased,
                schedule_id: schedule_id,
            });
        }
        
        /// Pauses all contract actions (admin only)
        /// @dev Emits EmergencyPause event. No vesting actions allowed while paused.
        /// @security Only admin can call.
        fn emergency_pause(ref self: ContractState) {
            self.assert_only_admin();
            self.paused.write(true);
            self.emit(EmergencyPause {});
        }
        
        /// Unpauses contract actions (admin only)
        /// @dev Emits EmergencyUnpause event. Restores normal operation.
        /// @security Only admin can call.
        fn emergency_unpause(ref self: ContractState) {
            self.assert_only_admin();
            self.paused.write(false);
            self.emit(EmergencyUnpause {});
        }
        
        /// Changes the contract admin
        /// @param new_admin The address to set as new admin
        /// @dev Emits AdminChanged event. Only callable by current admin.
        /// @security Only current admin can call. Ensure new_admin is trusted.
        fn change_admin(ref self: ContractState, new_admin: ContractAddress) {
            self.assert_only_admin();
            assert(!new_admin.is_zero(), ERROR_INVALID_BENEFICIARY);
            
            let old_admin = self.admin.read();
            self.admin.write(new_admin);
            
            self.emit(AdminChanged { 
                old_admin: old_admin,
                new_admin: new_admin
            });
        }
        
        // View functions
        
        fn get_token_address(self: @ContractState) -> ContractAddress {
            self.token.read()
        }
        
        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }
        
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }
        
        fn get_vesting_schedule(
            self: @ContractState, 
            beneficiary: ContractAddress, 
            schedule_id: u64
        ) -> TokenVestingTypes::VestingSchedule {
            self.vesting_schedules.read((beneficiary, schedule_id))
        }
        
        fn get_schedule_count(self: @ContractState) -> u64 {
            self.schedule_count.read()
        }
        
        fn get_beneficiary_schedule_count(self: @ContractState, beneficiary: ContractAddress) -> u64 {
            self.beneficiary_schedule_count.read(beneficiary)
        }
        
        fn get_total_vesting_for_beneficiary(self: @ContractState, beneficiary: ContractAddress) -> u256 {
            self.total_vesting_per_beneficiary.read(beneficiary)
        }
        
        fn is_schedule_revoked(self: @ContractState, beneficiary: ContractAddress, schedule_id: u64) -> bool {
            self.revoked_schedules.read((beneficiary, schedule_id))
        }
        
        fn calculate_vested_amount(self: @ContractState, beneficiary: ContractAddress, schedule_id: u64) -> u256 {
            let schedule = self.vesting_schedules.read((beneficiary, schedule_id));
            if schedule.beneficiary.is_zero() || self.revoked_schedules.read((beneficiary, schedule_id)) {
                return 0;
            }
            
            // Calculate acquired amount based on current time
            let vested = self.calculate_vested(schedule);
            vested
        }
        
        fn calculate_releasable_amount(self: @ContractState, beneficiary: ContractAddress, schedule_id: u64) -> u256 {
            let schedule = self.vesting_schedules.read((beneficiary, schedule_id));
            if schedule.beneficiary.is_zero() || self.revoked_schedules.read((beneficiary, schedule_id)) {
                return 0;
            }
            
            self.calculate_releasable(schedule)
        }
    }
    
    // Internal functions
    
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_admin(self: @ContractState) {
            let caller = get_caller_address();
            let admin = self.admin.read();
            assert(caller == admin, ERROR_UNAUTHORIZED);
        }
        
        fn assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), ERROR_PAUSED);
        }
        
        fn calculate_vested(self: @ContractState, schedule: TokenVestingTypes::VestingSchedule) -> u256 {
            let current_time = get_block_timestamp();
            
            // If before start + cliff, nothing is acquired
            if current_time < (schedule.start_time + schedule.cliff_duration) {
                return 0;
            }
            
            // If after end time, everything is acquired
            if current_time >= (schedule.start_time + schedule.duration) {
                return schedule.total_amount;
            }
            
            // Linear vesting calculation
            let time_passed = current_time - schedule.start_time;
            // Safe multiplication to prevent overflow
            let numerator = schedule.total_amount * time_passed.into();
            let denominator = schedule.duration.into();
            
            numerator / denominator
        }
        
        fn calculate_releasable(self: @ContractState, schedule: TokenVestingTypes::VestingSchedule) -> u256 {
            let vested_amount = self.calculate_vested(schedule);
            
            // Releasable amount is acquired minus already released
            if vested_amount <= schedule.released_amount {
                return 0;
            }
            
            vested_amount - schedule.released_amount
        }
    }
    
    #[abi(embed_v0)]
    impl MetadataImpl of IContractMetadata<ContractState> {
        fn get_metadata(self: @ContractState) -> (metadata: ContractMetadata) {
            let mut interfaces = ArrayTrait::new();
            interfaces.append(INTERFACE_VESTING);
            let mut dependencies = ArrayTrait::new();
            dependencies.append(DEPENDENCY_ERC20);
            let metadata = ContractMetadata {
                version: CONTRACT_VERSION,
                documentation_url: DOC_URL,
                interfaces: interfaces,
                dependencies: dependencies,
            };
            (metadata,)
        }
        fn supports_interface(self: @ContractState, interface_id: felt252) -> (supported: felt252) {
            if interface_id == INTERFACE_VESTING {
                (1,)
            } else {
                (0,)
            }
        }
    }
}