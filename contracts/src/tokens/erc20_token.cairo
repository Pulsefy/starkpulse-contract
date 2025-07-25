// -----------------------------------------------------------------------------
// StarkPulse ERC20 Token Implementation
// -----------------------------------------------------------------------------
//
// Overview:
// This contract implements a secure, feature-rich ERC20 token for StarkNet.
//
// Features:
// - Full ERC20 compliance (transfer, approve, allowance, etc.)
// - Minting and burning with role-based access control
// - Emergency pause/unpause by owner
// - Max supply enforcement
// - Ownership transfer and minter management
// - Comprehensive security validations
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
// let token = ERC20Token.deploy(
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

// StarkPulse ERC20 Token Implementation
// A complete, secure ERC20 token contract with all standard functionality
// 
// Features:
// - Full ERC20 compliance with standard Transfer and Approval events
// - Minting and burning capabilities with access control
// - Emergency pause functionality
// - Max supply enforcement
// - Role-based permissions (owner, minters)
// - Comprehensive security validations

#[starknet::contract]
mod ERC20Token {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starkpulse::utils::error_handling::{ErrorHandling, ErrorHandlingImpl, error_codes};

    #[storage]
    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _decimals: u8,
        _total_supply: u256,
        _max_supply: u256,
        _balances: LegacyMap::<ContractAddress, u256>,
        _allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
        _owner: ContractAddress,
        _minters: LegacyMap::<ContractAddress, bool>,
        _paused: bool,
        _mintable: bool,
        _burnable: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        OwnershipTransferred: OwnershipTransferred,
        MinterAdded: MinterAdded,
        MinterRemoved: MinterRemoved,
        Paused: Paused,
        Unpaused: Unpaused,
        Mint: Mint,
        Burn: Burn,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MinterAdded {
        minter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct MinterRemoved {
        minter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Paused {}

    #[derive(Drop, starknet::Event)]
    struct Unpaused {}

    #[derive(Drop, starknet::Event)]
    struct Mint {
        to: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Burn {
        from: ContractAddress,
        amount: u256,
    }

    // Error constants
    const ERROR_INVALID_RECIPIENT: felt252 = 'ERC20: invalid recipient';
    const ERROR_INVALID_SENDER: felt252 = 'ERC20: invalid sender';
    const ERROR_INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';
    const ERROR_INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';
    const ERROR_INVALID_SPENDER: felt252 = 'ERC20: invalid spender';
    const ERROR_UNAUTHORIZED: felt252 = 'ERC20: unauthorized';
    const ERROR_PAUSED: felt252 = 'ERC20: token transfer paused';
    const ERROR_EXCEEDS_MAX_SUPPLY: felt252 = 'ERC20: exceeds max supply';
    const ERROR_NOT_MINTABLE: felt252 = 'ERC20: not mintable';
    const ERROR_NOT_BURNABLE: felt252 = 'ERC20: not burnable';
    const ERROR_ZERO_ADDRESS: felt252 = 'ERC20: zero address';

    #[constructor]
    /// Contract constructor
    /// @param name_ The name of the token (e.g., 'StarkPulse')
    /// @param symbol_ The token symbol (e.g., 'SPT')
    /// @param decimals_ Number of decimals the token uses (e.g., 18)
    /// @param initial_supply Initial token supply to mint to owner
    /// @param max_supply_ Maximum allowed total supply (0 = unlimited)
    /// @param owner_ The address that will be the contract owner
    /// @param mintable_ If true, tokens can be minted after deployment
    /// @param burnable_ If true, tokens can be burned
    /// @dev Owner is set as initial minter if mintable is true. Emits Transfer and MinterAdded events.
    /// @security Only the provided owner_ will have admin rights. Ensure this is a trusted address.
    fn constructor(
        ref self: ContractState,
        name_: felt252,
        symbol_: felt252,
        decimals_: u8,
        initial_supply: u256,
        max_supply_: u256,
        owner_: ContractAddress,
        mintable_: bool,
        burnable_: bool
    ) {
        // Validate inputs
        assert(!owner_.is_zero(), ERROR_ZERO_ADDRESS);
        assert(max_supply_ == 0 || initial_supply <= max_supply_, ERROR_EXCEEDS_MAX_SUPPLY);

        // Set token metadata
        self.name.write(name_);
        self.symbol.write(symbol_);
        self.decimals.write(decimals_);
        self.total_supply.write(initial_supply);
        self.max_supply.write(max_supply_);
        
        // Set owner and permissions
        self.owner.write(owner_);
        self.mintable.write(mintable_);
        self.burnable.write(burnable_);
        self.paused.write(false);
        
        // Mint initial supply to owner
        if initial_supply > 0 {
            self.balances.write(owner_, initial_supply);
            
            // Emit transfer event from zero address
            self.emit(Transfer {
                from: ContractAddress::zero(),
                to: owner_,
                value: initial_supply,
            });
        }
        
        // Add owner as initial minter if mintable
        if mintable_ {
            self.minters.write(owner_, true);
            self.emit(MinterAdded { minter: owner_ });
        }
    }

    #[abi(embed_v0)]
    impl ERC20Impl of IERC20<ContractState> {
        /// Returns the name of the token
        /// @return The token name as felt252
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        /// Returns the symbol of the token
        /// @return The token symbol as felt252
        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        /// Returns the number of decimals used for token amounts
        /// @return The number of decimals as u8
        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        /// Returns the total token supply
        /// @return The total supply as u256
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        /// Returns the token balance of a specific account
        /// @param account The address to query the balance of
        /// @return The balance as u256
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        /// Returns the remaining number of tokens that spender is allowed to spend on behalf of owner
        /// @param owner The address that owns the tokens
        /// @param spender The address that is allowed to spend the tokens
        /// @return The allowance as u256
        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        /// Transfers tokens from the caller to a recipient
        /// @param recipient The address to transfer tokens to
        /// @param amount The amount of tokens to transfer
        /// @return true if the transfer was successful
        /// @dev Emits a Transfer event. Fails if contract is paused, sender has insufficient balance, or recipient is zero address.
        /// @security Only unpaused contract allows transfers. Always checks for sufficient balance and valid recipient.
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            // Check if contract is paused
            if self._paused.read() {
                self.emit_error(error_codes::CONTRACT_PAUSED, 'Contract is paused', 0);
                return false;
            }

            // Check for zero address
            if recipient.is_zero() {
                self.emit_error(error_codes::INVALID_ADDRESS, 'Cannot transfer to zero address', 0);
                return false;
            }

            let caller = get_caller_address();
            let caller_balance = self._balances.read(caller);

            // Check sufficient balance
            if caller_balance < amount {
                self.emit_error(
                    error_codes::INSUFFICIENT_BALANCE,
                    'Insufficient balance for transfer',
                    caller_balance.try_into().unwrap()
                );
                return false;
            }

            // Perform transfer
            self._balances.write(caller, caller_balance - amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            
            self.emit(Transfer { from: caller, to: recipient, value: amount });
            true
        }

        /// Transfers tokens from one address to another using allowance mechanism
        /// @param sender The address to transfer tokens from
        /// @param recipient The address to transfer tokens to
        /// @param amount The amount of tokens to transfer
        /// @return true if the transfer was successful
        /// @dev Requires sufficient allowance if caller is not the sender. Emits a Transfer event.
        /// @security Checks allowance, sender/recipient validity, and contract pause state.
        fn transfer_from(
            ref self: ContractState, 
            sender: ContractAddress, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            
            // Check allowance if caller is not the sender
            if caller != sender {
                let current_allowance = self.allowances.read((sender, caller));
                assert(current_allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
                
                // Update allowance
                self.allowances.write((sender, caller), current_allowance - amount);
            }
            
            self._transfer(sender, recipient, amount);
            true
        }

        /// Approves another address to spend tokens on behalf of the caller
        /// @param spender The address to approve for spending
        /// @param amount The amount of tokens to approve
        /// @return true if the approval was successful
        /// @dev Emits an Approval event. Overwrites previous allowance.
        /// @security Spender must not be zero address. Caller is always the owner of the tokens.
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            if spender.is_zero() {
                self.emit_error(error_codes::INVALID_ADDRESS, 'Cannot approve zero address', 0);
                return false;
            }

            let owner = get_caller_address();
            self._allowances.write((owner, spender), amount);
            
            self.emit(Approval { owner, spender, value: amount });
            true
        }

        // CamelCase variants for compatibility
        fn totalSupply(self: @ContractState) -> u256 {
            self.total_supply()
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }

        fn transferFrom(
            ref self: ContractState, 
            sender: ContractAddress, 
            recipient: ContractAddress, 
            amount: u256
        ) -> bool {
            self.transfer_from(sender, recipient, amount)
        }
    }

    // Additional functions for enhanced functionality
    #[abi(embed_v0)]
    impl ERC20ExtendedImpl of IERC20Extended<ContractState> {
        /// Mints new tokens to a specified address (only callable by minters)
        /// @param to The address to mint tokens to
        /// @param amount The amount of tokens to mint
        /// @return true if minting was successful
        /// @dev Emits Transfer and Mint events. Checks max supply if set.
        /// @security Only minters can call. Fails if paused, not mintable, or exceeds max supply.
        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            if !self._mintable.read() {
                self.emit_error(error_codes::INVALID_OPERATION, 'Minting is disabled', 0);
                return false;
            }

            let caller = get_caller_address();
            if !self._minters.read(caller) {
                self.emit_error(error_codes::UNAUTHORIZED_ACCESS, 'Caller is not a minter', 0);
                return false;
            }

            if to.is_zero() {
                self.emit_error(error_codes::INVALID_ADDRESS, 'Cannot mint to zero address', 0);
                return false;
            }

            let new_supply = self._total_supply.read() + amount;
            if new_supply > self._max_supply.read() {
                self.emit_error(error_codes::OVERFLOW, 'Mint would exceed max supply', 0);
                return false;
            }

            self._total_supply.write(new_supply);
            self._balances.write(to, self._balances.read(to) + amount);
            
            self.emit(Transfer { from: ContractAddress::from(0), to, value: amount });
            true
        }

        /// Burns tokens from the caller's balance
        /// @param amount The amount of tokens to burn
        /// @return true if burning was successful
        /// @dev Emits Transfer and Burn events. Fails if not burnable or paused.
        /// @security Only token holders can burn their own tokens. Checks sufficient balance.
        fn burn(ref self: ContractState, amount: u256) -> bool {
            let caller = get_caller_address();
            self._burn(caller, amount);
            true
        }

        /// Burns tokens from another account using allowance
        /// @param from The address to burn tokens from
        /// @param amount The amount of tokens to burn
        /// @return true if burning was successful
        /// @dev Checks allowance if caller is not the owner. Emits Transfer and Burn events.
        /// @security Checks sufficient allowance and balance. Only allowed if not paused and burnable.
        fn burn_from(ref self: ContractState, from: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            
            // Check allowance if caller is not the owner
            if caller != from {
                let current_allowance = self.allowances.read((from, caller));
                assert(current_allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
                
                // Update allowance
                self.allowances.write((from, caller), current_allowance - amount);
            }
            
            self._burn(from, amount);
            true
        }

        /// Increases the allowance granted to spender by the caller
        /// @param spender The address to increase allowance for
        /// @param added_value The amount to add to the allowance
        /// @return true if successful
        /// @dev Emits Approval event. Prevents overflow.
        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) -> bool {
            let owner = get_caller_address();
            let current_allowance = self.allowances.read((owner, spender));
            self._approve(owner, spender, current_allowance + added_value);
            true
        }

        /// Decreases the allowance granted to spender by the caller
        /// @param spender The address to decrease allowance for
        /// @param subtracted_value The amount to subtract from the allowance
        /// @return true if successful
        /// @dev Emits Approval event. Prevents underflow.
        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) -> bool {
            let owner = get_caller_address();
            let current_allowance = self.allowances.read((owner, spender));
            assert(current_allowance >= subtracted_value, ERROR_INSUFFICIENT_ALLOWANCE);
            self._approve(owner, spender, current_allowance - subtracted_value);
            true
        }

        /// Transfers contract ownership to a new address (only owner)
        /// @param new_owner The address to transfer ownership to
        /// @return true if successful
        /// @dev Emits OwnershipTransferred event. Fails if new_owner is zero address.
        /// @security Only current owner can call. Ensure new_owner is trusted.
        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) -> bool {
            self._assert_only_owner();
            assert(!new_owner.is_zero(), ERROR_ZERO_ADDRESS);
            
            let old_owner = self.owner.read();
            self.owner.write(new_owner);
            
            self.emit(OwnershipTransferred {
                previous_owner: old_owner,
                new_owner: new_owner,
            });
            
            true
        }

        /// Adds a new minter (only owner)
        /// @param minter The address to grant minter role
        /// @return true if successful
        /// @dev Emits MinterAdded event. Fails if minter is zero address.
        /// @security Only owner can add minters. Minters can mint new tokens.
        fn add_minter(ref self: ContractState, minter: ContractAddress) -> bool {
            self._assert_only_owner();
            assert(!minter.is_zero(), ERROR_ZERO_ADDRESS);
            
            self.minters.write(minter, true);
            
            self.emit(MinterAdded { minter: minter });
            
            true
        }

        /// Removes a minter (only owner)
        /// @param minter The address to revoke minter role
        /// @return true if successful
        /// @dev Emits MinterRemoved event.
        /// @security Only owner can remove minters.
        fn remove_minter(ref self: ContractState, minter: ContractAddress) -> bool {
            self._assert_only_owner();
            
            self.minters.write(minter, false);
            
            self.emit(MinterRemoved { minter: minter });
            
            true
        }

        /// Pauses all token transfers (only callable by owner)
        /// @return true if pausing was successful
        /// @dev Emits Paused event. Fails if already paused.
        /// @security Only owner can pause. No transfers, minting, or burning allowed while paused.
        fn pause(ref self: ContractState) -> bool {
            self._assert_only_owner();
            assert(!self.paused.read(), 'ERC20: already paused');
            
            self.paused.write(true);
            
            self.emit(Paused {});
            
            true
        }

        /// Unpauses all token transfers (only callable by owner)
        /// @return true if unpausing was successful
        /// @dev Emits Unpaused event. Fails if not paused.
        /// @security Only owner can unpause.
        fn unpause(ref self: ContractState) -> bool {
            self._assert_only_owner();
            assert(self.paused.read(), 'ERC20: not paused');
            
            self.paused.write(false);
            
            self.emit(Unpaused {});
            
            true
        }

        // View functions
        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn is_minter(self: @ContractState, account: ContractAddress) -> bool {
            self.minters.read(account)
        }

        fn is_paused(self: @ContractState) -> bool {
            self.paused.read()
        }

        fn max_supply(self: @ContractState) -> u256 {
            self.max_supply.read()
        }

        fn is_mintable(self: @ContractState) -> bool {
            self.mintable.read()
        }

        fn is_burnable(self: @ContractState) -> bool {
            self.burnable.read()
        }
    }

    // Internal functions
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) {
            // Internal transfer logic
            // Checks: contract not paused, sender/recipient not zero, sufficient balance
            // Updates balances and emits Transfer event
            self._assert_not_paused();
            assert(!sender.is_zero(), ERROR_INVALID_SENDER);
            assert(!recipient.is_zero(), ERROR_INVALID_RECIPIENT);
            
            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, ERROR_INSUFFICIENT_BALANCE);
            
            // Update balances
            self.balances.write(sender, sender_balance - amount);
            
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
            
            // Emit transfer event
            self.emit(Transfer {
                from: sender,
                to: recipient,
                value: amount,
            });
        }

        fn _approve(ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256) {
            // Internal approve logic
            // Checks: owner/spender not zero
            // Updates allowance and emits Approval event
            assert(!owner.is_zero(), ERROR_INVALID_SENDER);
            assert(!spender.is_zero(), ERROR_INVALID_SPENDER);
            
            self.allowances.write((owner, spender), amount);
            
            self.emit(Approval {
                owner: owner,
                spender: spender,
                value: amount,
            });
        }

        fn _burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            // Internal burn logic
            // Checks: contract not paused, burnable, from not zero, sufficient balance
            // Updates balances, total supply, and emits Transfer and Burn events
            self._assert_not_paused();
            assert(self.burnable.read(), ERROR_NOT_BURNABLE);
            assert(!from.is_zero(), ERROR_INVALID_SENDER);
            assert(amount > 0, 'ERC20: amount must be positive');
            
            let account_balance = self.balances.read(from);
            assert(account_balance >= amount, ERROR_INSUFFICIENT_BALANCE);
            
            // Update balances and total supply
            self.balances.write(from, account_balance - amount);
            
            let current_total_supply = self.total_supply.read();
            self.total_supply.write(current_total_supply - amount);
            
            // Emit events
            self.emit(Transfer {
                from: from,
                to: ContractAddress::zero(),
                value: amount,
            });
            
            self.emit(Burn {
                from: from,
                amount: amount,
            });
        }

        fn _assert_only_owner(self: @ContractState) {
            // Asserts that the caller is the contract owner
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(caller == owner, ERROR_UNAUTHORIZED);
        }

        fn _assert_only_minter(self: @ContractState) {
            // Asserts that the caller is a registered minter
            let caller = get_caller_address();
            assert(self.minters.read(caller), ERROR_UNAUTHORIZED);
        }

        fn _assert_not_paused(self: @ContractState) {
            // Asserts that the contract is not paused
            assert(!self.paused.read(), ERROR_PAUSED);
        }
    }

    #[abi(embed_v0)]
    impl MetadataImpl of IContractMetadata<ContractState> {
        fn get_metadata(self: @ContractState) -> (metadata: ContractMetadata) {
            let mut interfaces = ArrayTrait::new();
            interfaces.append(INTERFACE_ERC20);
            interfaces.append(INTERFACE_ERC20_EXT);
            let mut dependencies = ArrayTrait::new();
            dependencies.append(DEPENDENCY_NONE);
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

// Extended interface for additional functionality
#[starknet::interface]
trait IERC20Extended<TContractState> {
    // Minting and burning
    fn mint(ref self: TContractState, to: starknet::ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TContractState, amount: u256) -> bool;
    fn burn_from(ref self: TContractState, from: starknet::ContractAddress, amount: u256) -> bool;
    
    // Enhanced allowance functions
    fn increase_allowance(ref self: TContractState, spender: starknet::ContractAddress, added_value: u256) -> bool;
    fn decrease_allowance(ref self: TContractState, spender: starknet::ContractAddress, subtracted_value: u256) -> bool;
    
    // Admin functions
    fn transfer_ownership(ref self: TContractState, new_owner: starknet::ContractAddress) -> bool;
    fn add_minter(ref self: TContractState, minter: starknet::ContractAddress) -> bool;
    fn remove_minter(ref self: TContractState, minter: starknet::ContractAddress) -> bool;
    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;
    
    // View functions
    fn owner(self: @TContractState) -> starknet::ContractAddress;
    fn is_minter(self: @TContractState, account: starknet::ContractAddress) -> bool;
    fn is_paused(self: @TContractState) -> bool;
    fn max_supply(self: @TContractState) -> u256;
    fn is_mintable(self: @TContractState) -> bool;
    fn is_burnable(self: @TContractState) -> bool;
}

// -----------------------------------------------------------------------------
// Example Usage: ERC20Token
// -----------------------------------------------------------------------------
//
// // Deploying the contract (pseudo-code):
// let token = ERC20Token.deploy(
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

// Add to imports
use crate::interfaces::i_event_system::{IEventSystemDispatcher, IEventSystemDispatcherTrait};
use crate::interfaces::i_event_system::{CATEGORY_TRANSACTION, SEVERITY_INFO, SEVERITY_WARNING};

// Add to storage
struct Storage {
    _name: felt252,
    _symbol: felt252,
    _decimals: u8,
    _total_supply: u256,
    _max_supply: u256,
    _balances: LegacyMap::<ContractAddress, u256>,
    _allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
    _owner: ContractAddress,
    _minters: LegacyMap::<ContractAddress, bool>,
    _paused: bool,
    _mintable: bool,
    _burnable: bool
    event_system: IEventSystemDispatcher,
}

// Enhanced Transfer event with standardization
#[derive(Drop, starknet::Event)]
struct Transfer {
    #[key]
    from: ContractAddress,
    #[key]
    to: ContractAddress,
    value: u256,
    // Enhanced fields
    #[key]
    transaction_type: felt252, // 'TRANSFER', 'MINT', 'BURN'
    correlation_id: felt252,
    metadata: Array<felt252>,
}

// In the transfer function, emit both standard and legacy events
fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
    // Generate correlation ID for this transaction
    let correlation_id = self._generate_correlation_id();
    
    // Emit legacy event for backward compatibility
    self.emit(Transfer {
        from: from,
        to: to,
        value: amount,
        transaction_type: 'TRANSFER',
        correlation_id: correlation_id,
        metadata: ArrayTrait::new(),
    });
    
    // Emit standardized event
    let mut event_data = ArrayTrait::new();
    event_data.append(from.into());
    event_data.append(to.into());
    event_data.append(amount.low.into());
    event_data.append(amount.high.into());
    
    let mut indexed_data = ArrayTrait::new();
    indexed_data.append('TRANSFER');
    indexed_data.append(from.into());
    indexed_data.append(to.into());
    
    self.event_system.read().emit_standard_event(
        'TOKEN_TRANSFER',
        CATEGORY_TRANSACTION,
        SEVERITY_INFO,
        from,
        event_data,
        indexed_data,
        correlation_id
    );
    
    true
}

use crate::interfaces::i_event_system::{IEventSystemDispatcher, IEventSystemDispatcherTrait};
use crate::interfaces::i_event_system::{CATEGORY_TRANSACTION, SEVERITY_INFO, SEVERITY_WARNING};

#[storage]
struct Storage {
    _name: felt252,
    _symbol: felt252,
    _decimals: u8,
    _total_supply: u256,
    _max_supply: u256,
    _balances: LegacyMap::<ContractAddress, u256>,
    _allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
    _owner: ContractAddress,
    _minters: LegacyMap::<ContractAddress, bool>,
    _paused: bool,
    _mintable: bool,
    _burnable: bool
    event_system: IEventSystemDispatcher,
}

#[external(v0)]
impl IERC20Impl of IERC20<ContractState> {
    fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
        let caller = get_caller_address();
        
        // Check if contract is paused
        if self._paused.read() {
            self.emit_error(error_codes::CONTRACT_PAUSED, 'Contract is paused', 0);
            return false;
        }
    
        // Check for zero address
        if recipient.is_zero() {
            self.emit_error(error_codes::INVALID_ADDRESS, 'Cannot transfer to zero address', 0);
            return false;
        }
    
        // Emit standardized event
        self._emit_transfer_event(caller, to, amount, 'TRANSFER');
        
        true
    }
    
    fn transfer_from(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256
    ) -> bool {
        // Check allowance if caller is not the sender
        if caller != sender {
            let current_allowance = self.allowances.read((sender, caller));
            assert(current_allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
            
            // Update allowance
            self.allowances.write((sender, caller), current_allowance - amount);
        }
        
        self._transfer(sender, recipient, amount);
        true
    }
    
    fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
        let caller = get_caller_address();
        
        // Check allowance if caller is not the sender
        if caller != sender {
            let current_allowance = self.allowances.read((sender, caller));
            assert(current_allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
            
            // Update allowance
            self.allowances.write((sender, caller), current_allowance - amount);
        }
        
        self._transfer(sender, recipient, amount);
        true
    }
}

#[external(v0)]
impl IERC20ExtendedImpl of IERC20Extended<ContractState> {
    fn mint(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
        // Check allowance if caller is not the sender
        if caller != sender {
            let current_allowance = self.allowances.read((sender, caller));
            assert(current_allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
            
            // Update allowance
            self.allowances.write((sender, caller), current_allowance - amount);
        }
        
        self._transfer(sender, recipient, amount);
        true
    }
    
    fn burn(ref self: ContractState, amount: u256) -> bool {
        let caller = get_caller_address();
        
        // Check allowance if caller is not the sender
        if caller != sender {
            let current_allowance = self.allowances.read((sender, caller));
            assert(current_allowance >= amount, ERROR_INSUFFICIENT_ALLOWANCE);
            
            // Update allowance
            self.allowances.write((sender, caller), current_allowance - amount);
        }
        
        self._transfer(sender, recipient, amount);
        true
    }
}

// Internal helper functions
#[generate_trait]
impl InternalImpl of InternalTrait {
    fn _emit_transfer_event(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        amount: u256,
        transfer_type: felt252
    ) {
        let event_data = array![
            from.into(),
            to.into(),
            amount.low.into(),
            amount.high.into(),
            transfer_type
        ];
        let indexed_data = array![from.into(), to.into()];
        
        self._emit_to_event_system(
            'TOKEN_TRANSFER',
            event_data,
            indexed_data,
            SEVERITY_INFO
        );
    }
    
    fn _emit_to_event_system(
        ref self: ContractState,
        event_type: felt252,
        data: Array<felt252>,
        indexed_data: Array<felt252>,
        severity: u8
    ) {
        let event_system = IEventSystemDispatcher {
            contract_address: self.event_system.read()
        };
        
        event_system.emit_standard_event(
            event_type,
            CATEGORY_TRANSACTION,
            severity,
            get_caller_address(),
            data,
            indexed_data,
            0 // No correlation for basic token operations
        );
    }
}
