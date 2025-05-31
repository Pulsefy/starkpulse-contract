// StarkPulse Native Token Implementation
// The official token of the StarkPulse ecosystem
//
// Token Details:
// - Name: StarkPulse Token
// - Symbol: SPT
// - Decimals: 18
// - Initial Supply: 100,000,000 SPT
// - Max Supply: 1,000,000,000 SPT
// - Features: Mintable, Burnable, Pausable
//
// This token serves as the native currency for the StarkPulse DeFi platform,
// enabling governance, staking, and transaction fee payments.

#[starknet::contract]
mod StarkPulseToken {
    use starknet::{ContractAddress, get_caller_address};
    use crate::tokens::erc20_token::{ERC20Token, IERC20Extended};
    use crate::interfaces::i_erc20::IERC20;
    use contracts::src::utils::contract_metadata::{ContractMetadata, IContractMetadata};
    use array::ArrayTrait;

    // Metadata constants
    const CONTRACT_VERSION: felt252 = '1.0.0';
    const DOC_URL: felt252 = 'https://github.com/Pulsefy/starkpulse-contract?tab=readme-ov-file#starkpulse-token';
    const INTERFACE_ERC20: felt252 = 'IERC20';
    const INTERFACE_ERC20_EXT: felt252 = 'IERC20Extended';
    const DEPENDENCY_ERC20: felt252 = 'ERC20Token';

    #[storage]
    struct Storage {
        erc20: ERC20Token::ContractState,
    }

    /// Initializes the StarkPulse Token with predefined parameters
    /// @param owner The address that will own the token contract and receive initial supply
    /// Sets up the token with StarkPulse-specific tokenomics and features
    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Initialize with StarkPulse token parameters
        self.erc20.constructor(
            'StarkPulse Token',     // name
            'SPT',                  // symbol
            18,                     // decimals
            100000000000000000000000000, // initial_supply: 100M tokens
            1000000000000000000000000000, // max_supply: 1B tokens
            owner,                  // owner
            true,                   // mintable
            true                    // burnable
        );
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.erc20.decimals()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.erc20.transfer(recipient, amount)
        }

        fn transfer_from(
            ref self: ContractState, 
            sender: ContractAddress, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            self.erc20.transfer_from(sender, recipient, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20.approve(spender, amount)
        }

        fn totalSupply(self: @ContractState) -> u256 {
            self.erc20.totalSupply()
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balanceOf(account)
        }

        fn transferFrom(
            ref self: ContractState, 
            sender: ContractAddress, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            self.erc20.transferFrom(sender, recipient, amount)
        }
    }

    #[abi(embed_v0)]
    impl ERC20ExtendedImpl of IERC20Extended<ContractState> {
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            self.erc20.mint(to, amount)
        }

        fn burn(ref self: ContractState, amount: u256) -> bool {
            self.erc20.burn(amount)
        }

        fn burn_from(ref self: ContractState, from: ContractAddress, amount: u256) -> bool {
            self.erc20.burn_from(from, amount)
        }

        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) -> bool {
            self.erc20.increase_allowance(spender, added_value)
        }

        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) -> bool {
            self.erc20.decrease_allowance(spender, subtracted_value)
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) -> bool {
            self.erc20.transfer_ownership(new_owner)
        }

        fn add_minter(ref self: ContractState, minter: ContractAddress) -> bool {
            self.erc20.add_minter(minter)
        }

        fn remove_minter(ref self: ContractState, minter: ContractAddress) -> bool {
            self.erc20.remove_minter(minter)
        }

        fn pause(ref self: ContractState) -> bool {
            self.erc20.pause()
        }

        fn unpause(ref self: ContractState) -> bool {
            self.erc20.unpause()
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.erc20.owner()
        }

        fn is_minter(self: @ContractState, account: ContractAddress) -> bool {
            self.erc20.is_minter(account)
        }

        fn is_paused(self: @ContractState) -> bool {
            self.erc20.is_paused()
        }

        fn max_supply(self: @ContractState) -> u256 {
            self.erc20.max_supply()
        }

        fn is_mintable(self: @ContractState) -> bool {
            self.erc20.is_mintable()
        }

        fn is_burnable(self: @ContractState) -> bool {
            self.erc20.is_burnable()
        }
    }

    #[abi(embed_v0)]
    impl MetadataImpl of IContractMetadata<ContractState> {
        fn get_metadata(self: @ContractState) -> (metadata: ContractMetadata) {
            let mut interfaces = ArrayTrait::new();
            interfaces.append(INTERFACE_ERC20);
            interfaces.append(INTERFACE_ERC20_EXT);
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
            if interface_id == INTERFACE_ERC20 || interface_id == INTERFACE_ERC20_EXT {
                (1,)
            } else {
                (0,)
            }
        }
    }
}
