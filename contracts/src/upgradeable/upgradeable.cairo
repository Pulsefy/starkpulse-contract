#[starknet::contract]
pub mod upgradeable {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_block_timestamp;
    use starknet::class_hash::ClassHash;
    use starknet::syscalls::replace_class_syscall;

    use starkpulse_contract::interfaces::i_upgradeable::IUpgradeable;

    #[storage]
    struct Storage {
        admin: ContractAddress,
        version: u256, // Track contract version
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        new_class_hash: ClassHash,
        version: u256,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        self.version.write(1); // Initial version
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash, new_version: u256) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Only admin can upgrade');
            assert(new_version > self.version.read(), 'Version must increase');
            assert(!new_class_hash.is_zero(), 'Invalid class hash');
            
            replace_class_syscall(new_class_hash).expect('Upgrade failed');
            self.version.write(new_version); // Update version in storage
            
            self.emit(Event::Upgraded(Upgraded {
                new_class_hash,
                version: new_version,
                timestamp: get_block_timestamp(),
            }));
        }

        fn get_admin(self: @ContractState) -> ContractAddress {
            self.admin.read()
        }

        fn get_version(self: @ContractState) -> u256 {
            self.version.read()
        }
    }
} 