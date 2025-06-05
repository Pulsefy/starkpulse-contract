// -----------------------------------------------------------------------------
// StarkPulse Token Implementation
// -----------------------------------------------------------------------------
//
// Overview:
// This contract implements the StarkPulse native token, extending ERC20 functionality
// with additional features for analytics, governance, and integration with the StarkPulse ecosystem.
//
// Features:
// - ERC20 compliance (transfer, approve, allowance, etc.)
// - Minting and burning with access control
// - Emergency pause/unpause by owner
// - Max supply enforcement
// - Role-based permissions (owner, minters)
// - Analytics hooks for tracking on-chain activity
//
// Security Considerations:
// - Only designated minters can mint new tokens; only owner can add/remove minters.
// - Transfers, minting, and burning are blocked when the contract is paused.
// - All critical functions validate caller permissions and input values.
// - Zero address checks prevent accidental token loss.
// - Max supply is enforced on minting.
//
// Example Usage:
//
// // Deploying the contract (pseudo-code):
// let token = StarkPulseToken.deploy(
//     name='StarkPulse',
//     symbol='SPT',
//     decimals=18,
//     initial_supply=1000000,
//     max_supply=10000000,
//     owner=OWNER_ADDRESS,
//     mintable=true,
//     burnable=true
// );
//
// // Transferring tokens:
// token.transfer(RECIPIENT_ADDRESS, 100);
//
// // Minting tokens (as minter):
// token.mint(USER_ADDRESS, 500);
//
// // Burning tokens:
// token.burn(50);
//
// // Pausing/unpausing (as owner):
// token.pause();
// token.unpause();
//
// For integration and more examples, see INTEGRATION_GUIDE.md.
// -----------------------------------------------------------------------------

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
        // erc20: The underlying ERC20Token contract state, reused for StarkPulseToken
        erc20: ERC20Token::ContractState,
    }

    /// Initializes the StarkPulse Token with predefined parameters
    /// @param owner The address that will own the token contract and receive initial supply
    /// @dev Sets up the token with StarkPulse-specific tokenomics and features.
    /// @security Only the provided owner will have admin rights. Ensure this is a trusted address.
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
        /// Returns the name of the token
        /// @return The token name as felt252
        fn name(self: @ContractState) -> felt252 {
            self.erc20.name()
        }

        /// Returns the symbol of the token
        /// @return The token symbol as felt252
        fn symbol(self: @ContractState) -> felt252 {
            self.erc20.symbol()
        }

        /// Returns the number of decimals used for token amounts
        /// @return The number of decimals as u8
        fn decimals(self: @ContractState) -> u8 {
            self.erc20.decimals()
        }

        /// Returns the total token supply
        /// @return The total supply as u256
        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        /// Returns the token balance of a specific account
        /// @param account The address to query the balance of
        /// @return The balance as u256
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(account)
        }

        /// Returns the remaining number of tokens that spender is allowed to spend on behalf of owner
        /// @param owner The address that owns the tokens
        /// @param spender The address that is allowed to spend the tokens
        /// @return The allowance as u256
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.erc20.allowance(owner, spender)
        }

        /// Transfers tokens from the caller to a recipient
        /// @param recipient The address to transfer tokens to
        /// @param amount The amount of tokens to transfer
        /// @return true if the transfer was successful
        /// Emits a Transfer event
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            self.erc20.transfer(recipient, amount)
        }

        /// Transfers tokens from one address to another using allowance mechanism
        /// @param sender The address to transfer tokens from
        /// @param recipient The address to transfer tokens to
        /// @param amount The amount of tokens to transfer
        /// @return true if the transfer was successful
        /// Requires sufficient allowance if caller is not the sender
        /// Emits a Transfer event
        fn transfer_from(
            ref self: ContractState, 
            sender: ContractAddress, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            self.erc20.transfer_from(sender, recipient, amount)
        }

        /// Approves another address to spend tokens on behalf of the caller
        /// @param spender The address to approve for spending
        /// @param amount The amount of tokens to approve
        /// @return true if the approval was successful
        /// Emits an Approval event
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
        /// Mints new tokens to a specified address (only callable by minters)
        /// @param to The address to mint tokens to
        /// @param amount The amount of tokens to mint
        /// @return true if minting was successful
        /// @dev Emits Transfer and Mint events. Checks max supply if set.
        /// @security Only minters can call. Fails if paused, not mintable, or exceeds max supply.
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            self.erc20.mint(to, amount)
        }

        /// Burns tokens from the caller's balance
        /// @param amount The amount of tokens to burn
        /// @return true if burning was successful
        /// @dev Emits Transfer and Burn events. Fails if not burnable or paused.
        /// @security Only token holders can burn their own tokens. Checks sufficient balance.
        fn burn(ref self: ContractState, amount: u256) -> bool {
            self.erc20.burn(amount)
        }

        /// Burns tokens from another account using allowance
        /// @param from The address to burn tokens from
        /// @param amount The amount of tokens to burn
        /// @return true if burning was successful
        /// @dev Checks allowance if caller is not the owner. Emits Transfer and Burn events.
        /// @security Checks sufficient allowance and balance. Only allowed if not paused and burnable.
        fn burn_from(ref self: ContractState, from: ContractAddress, amount: u256) -> bool {
            self.erc20.burn_from(from, amount)
        }

        /// Increases the allowance granted to spender by the caller
        /// @param spender The address to increase allowance for
        /// @param added_value The amount to add to the allowance
        /// @return true if successful
        /// @dev Emits Approval event. Prevents overflow.
        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) -> bool {
            self.erc20.increase_allowance(spender, added_value)
        }

        /// Decreases the allowance granted to spender by the caller
        /// @param spender The address to decrease allowance for
        /// @param subtracted_value The amount to subtract from the allowance
        /// @return true if successful
        /// @dev Emits Approval event. Prevents underflow.
        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) -> bool {
            self.erc20.decrease_allowance(spender, subtracted_value)
        }

        /// Transfers contract ownership to a new address (only owner)
        /// @param new_owner The address to transfer ownership to
        /// @return true if successful
        /// @dev Emits OwnershipTransferred event. Fails if new_owner is zero address.
        /// @security Only current owner can call. Ensure new_owner is trusted.
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) -> bool {
            self.erc20.transfer_ownership(new_owner)
        }

        /// Adds a new minter (only owner)
        /// @param minter The address to grant minter role
        /// @return true if successful
        /// @dev Emits MinterAdded event. Fails if minter is zero address.
        /// @security Only owner can add minters. Minters can mint new tokens.
        fn add_minter(ref self: ContractState, minter: ContractAddress) -> bool {
            self.erc20.add_minter(minter)
        }

        /// Removes a minter (only owner)
        /// @param minter The address to revoke minter role
        /// @return true if successful
        /// @dev Emits MinterRemoved event.
        /// @security Only owner can remove minters.
        fn remove_minter(ref self: ContractState, minter: ContractAddress) -> bool {
            self.erc20.remove_minter(minter)
        }

        /// Pauses all token transfers (only callable by owner)
        /// @return true if pausing was successful
        /// @dev Emits Paused event. Fails if already paused.
        /// @security Only owner can pause. No transfers, minting, or burning allowed while paused.
        fn pause(ref self: ContractState) -> bool {
            self.erc20.pause()
        }

        /// Unpauses all token transfers (only callable by owner)
        /// @return true if unpausing was successful
        /// @dev Emits Unpaused event. Fails if not paused.
        /// @security Only owner can unpause.
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
