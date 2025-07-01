// utils/pausable.cairo
#[starknet::contract]
mod Pausable {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use crate::interfaces::i_pausable::IPausable;
    use crate::utils::access_control::AccessControl;
    use crate::utils::error_handling::{Error, assert};
    

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Paused: Paused,
        Unpaused: Unpaused
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {
        caller: ContractAddress,
        timestamp: u64,
        function_selector: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct Unpaused {
        caller: ContractAddress,
        timestamp: u64
    }

    #[storage]
    struct Storage {
        paused: bool,
        function_pauses: LegacyMap<felt252, bool>
    }

    #[external(v0)]
    impl PausableImpl of IPausable<ContractState> {
        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn is_function_paused(self: @ContractState, selector: felt252) -> bool {
            self.paused.read() || self.function_pauses.read(selector)
        }

        fn pause(ref self: ContractState) {
            AccessControl::assert_only_role('PAUSER', get_caller_address());
            self.paused.write(true);
            self.emit(Event::Paused(Paused {
                caller: get_caller_address(),
                timestamp: get_block_timestamp(),
                function_selector: 0
            }));
        }

        fn unpause(ref self: ContractState) {
            AccessControl::assert_only_role('PAUSER', get_caller_address());
            self.paused.write(false);
            self.emit(Event::Unpaused(Unpaused {
                caller: get_caller_address(),
                timestamp: get_block_timestamp()
            }));
        }

        fn pause_function(ref self: ContractState, selector: felt252) {
            AccessControl::assert_only_role('FUNCTION_PAUSER', get_caller_address());
            self.function_pauses.write(selector, true);
            self.emit(Event::Paused(Paused {
                caller: get_caller_address(),
                timestamp: get_block_timestamp(),
                function_selector: selector
            }));
        }

        fn unpause_function(ref self: ContractState, selector: felt252) {
            AccessControl::assert_only_role('FUNCTION_PAUSER', get_caller_address());
            self.function_pauses.write(selector, false);
            self.emit(Event::Unpaused(Unpaused {
                caller: get_caller_address(),
                timestamp: get_block_timestamp()
            }));
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_not_paused(self: @ContractState) {
            assert(!self.paused.read(), Error::ContractPaused);
        }

        fn _assert_function_not_paused(self: @ContractState, selector: felt252) {
            assert(
                !self.paused.read() && !self.function_pauses.read(selector),
                Error::FunctionPaused
            );
        }
    }
}


