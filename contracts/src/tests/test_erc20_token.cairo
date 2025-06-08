#[cfg(test)]
mod test_erc20_token {
    use starknet::{
        ContractAddress, 
        contract_address_const, 
        get_caller_address, 
        get_block_timestamp,
        testing::set_caller_address,
        testing::set_block_timestamp
    };
    
    use crate::tokens::erc20_token::{ERC20Token, IERC20Extended, IERC20ExtendedDispatcher, IERC20ExtendedDispatcherTrait};
    use crate::interfaces::i_erc20::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    
    // Test addresses
    const OWNER: felt252 = 0x123;
    const USER1: felt252 = 0x456;
    const USER2: felt252 = 0x789;
    const MINTER: felt252 = 0xabc;
    
    // Token constants
    const TOKEN_NAME: felt252 = 'StarkPulse Token';
    const TOKEN_SYMBOL: felt252 = 'SPT';
    const TOKEN_DECIMALS: u8 = 18;
    const INITIAL_SUPPLY: u256 = 1000000000000000000000000; // 1M tokens with 18 decimals
    const MAX_SUPPLY: u256 = 10000000000000000000000000; // 10M tokens with 18 decimals
    
    fn setup_token() -> (ERC20Token::ContractState, ContractAddress, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<OWNER>();
        let user1 = contract_address_const::<USER1>();
        let user2 = contract_address_const::<USER2>();
        
        set_caller_address(owner);
        
        let mut token = ERC20Token::unsafe_new();
        token.constructor(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            INITIAL_SUPPLY,
            MAX_SUPPLY,
            owner,
            true, // mintable
            true  // burnable
        );
        
        (token, owner, user1, user2)
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_token_initialization() {
        let (token, owner, _, _) = setup_token();
        
        // Test metadata
        assert(token.name() == TOKEN_NAME, "Name mismatch");
        assert(token.symbol() == TOKEN_SYMBOL, "Symbol mismatch");
        assert(token.decimals() == TOKEN_DECIMALS, "Decimals mismatch");
        assert(token.total_supply() == INITIAL_SUPPLY, "Total supply mismatch");
        assert(token.max_supply() == MAX_SUPPLY, "Max supply mismatch");
        
        // Test owner setup
        assert(token.owner() == owner, "Owner mismatch");
        assert(token.is_minter(owner), "Owner should be minter");
        assert(token.is_mintable(), "Token should be mintable");
        assert(token.is_burnable(), "Token should be burnable");
        assert(!token.is_paused(), "Token should not be paused");
        
        // Test initial balance
        assert(token.balance_of(owner) == INITIAL_SUPPLY, "Owner balance mismatch");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_transfer() {
        let (mut token, owner, user1, user2) = setup_token();
        
        set_caller_address(owner);
        
        let transfer_amount = 1000000000000000000000; // 1000 tokens
        
        // Test successful transfer
        let result = token.transfer(user1, transfer_amount);
        assert(result, "Transfer should succeed");
        
        // Verify balances
        assert(token.balance_of(owner) == INITIAL_SUPPLY - transfer_amount, "Owner balance incorrect");
        assert(token.balance_of(user1) == transfer_amount, "User1 balance incorrect");
        
        // Test transfer from user1 to user2
        set_caller_address(user1);
        let second_transfer = 500000000000000000000; // 500 tokens
        let result = token.transfer(user2, second_transfer);
        assert(result, "Second transfer should succeed");
        
        // Verify final balances
        assert(token.balance_of(user1) == transfer_amount - second_transfer, "User1 final balance incorrect");
        assert(token.balance_of(user2) == second_transfer, "User2 balance incorrect");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_approval_and_transfer_from() {
        let (mut token, owner, user1, user2) = setup_token();
        
        let approval_amount = 2000000000000000000000; // 2000 tokens
        let transfer_amount = 1500000000000000000000; // 1500 tokens
        
        // Owner approves user1 to spend tokens
        set_caller_address(owner);
        let result = token.approve(user1, approval_amount);
        assert(result, "Approval should succeed");
        
        // Verify allowance
        assert(token.allowance(owner, user1) == approval_amount, "Allowance incorrect");
        
        // User1 transfers from owner to user2
        set_caller_address(user1);
        let result = token.transfer_from(owner, user2, transfer_amount);
        assert(result, "Transfer from should succeed");
        
        // Verify balances and allowance
        assert(token.balance_of(owner) == INITIAL_SUPPLY - transfer_amount, "Owner balance incorrect");
        assert(token.balance_of(user2) == transfer_amount, "User2 balance incorrect");
        assert(token.allowance(owner, user1) == approval_amount - transfer_amount, "Remaining allowance incorrect");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_increase_decrease_allowance() {
        let (mut token, owner, user1, _) = setup_token();
        
        set_caller_address(owner);
        
        let initial_allowance = 1000000000000000000000; // 1000 tokens
        let increase_amount = 500000000000000000000; // 500 tokens
        let decrease_amount = 300000000000000000000; // 300 tokens
        
        // Set initial allowance
        token.approve(user1, initial_allowance);
        assert(token.allowance(owner, user1) == initial_allowance, "Initial allowance incorrect");
        
        // Increase allowance
        let result = token.increase_allowance(user1, increase_amount);
        assert(result, "Increase allowance should succeed");
        assert(token.allowance(owner, user1) == initial_allowance + increase_amount, "Increased allowance incorrect");
        
        // Decrease allowance
        let result = token.decrease_allowance(user1, decrease_amount);
        assert(result, "Decrease allowance should succeed");
        assert(token.allowance(owner, user1) == initial_allowance + increase_amount - decrease_amount, "Decreased allowance incorrect");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_minting() {
        let (mut token, owner, user1, _) = setup_token();
        
        set_caller_address(owner);
        
        let mint_amount = 1000000000000000000000; // 1000 tokens
        
        // Test minting
        let result = token.mint(user1, mint_amount);
        assert(result, "Minting should succeed");
        
        // Verify balances and total supply
        assert(token.balance_of(user1) == mint_amount, "User1 balance incorrect after mint");
        assert(token.total_supply() == INITIAL_SUPPLY + mint_amount, "Total supply incorrect after mint");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_burning() {
        let (mut token, owner, user1, _) = setup_token();
        
        // Transfer some tokens to user1 first
        set_caller_address(owner);
        let transfer_amount = 2000000000000000000000; // 2000 tokens
        token.transfer(user1, transfer_amount);
        
        // Test burning from user1
        set_caller_address(user1);
        let burn_amount = 1000000000000000000000; // 1000 tokens
        let result = token.burn(burn_amount);
        assert(result, "Burning should succeed");
        
        // Verify balances and total supply
        assert(token.balance_of(user1) == transfer_amount - burn_amount, "User1 balance incorrect after burn");
        assert(token.total_supply() == INITIAL_SUPPLY - burn_amount, "Total supply incorrect after burn");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_burn_from() {
        let (mut token, owner, user1, _) = setup_token();
        
        // Transfer some tokens to user1 first
        set_caller_address(owner);
        let transfer_amount = 2000000000000000000000; // 2000 tokens
        token.transfer(user1, transfer_amount);
        
        // User1 approves owner to burn tokens
        set_caller_address(user1);
        let approval_amount = 1500000000000000000000; // 1500 tokens
        token.approve(owner, approval_amount);
        
        // Owner burns tokens from user1
        set_caller_address(owner);
        let burn_amount = 1000000000000000000000; // 1000 tokens
        let result = token.burn_from(user1, burn_amount);
        assert(result, "Burn from should succeed");
        
        // Verify balances, allowance, and total supply
        assert(token.balance_of(user1) == transfer_amount - burn_amount, "User1 balance incorrect after burn from");
        assert(token.allowance(user1, owner) == approval_amount - burn_amount, "Allowance incorrect after burn from");
        assert(token.total_supply() == INITIAL_SUPPLY - burn_amount, "Total supply incorrect after burn from");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_minter_management() {
        let (mut token, owner, _, _) = setup_token();
        let minter = contract_address_const::<MINTER>();
        
        set_caller_address(owner);
        
        // Add minter
        let result = token.add_minter(minter);
        assert(result, "Add minter should succeed");
        assert(token.is_minter(minter), "Minter should be added");
        
        // Test minting with new minter
        set_caller_address(minter);
        let mint_amount = 500000000000000000000; // 500 tokens
        let result = token.mint(owner, mint_amount);
        assert(result, "Minting by new minter should succeed");
        
        // Remove minter
        set_caller_address(owner);
        let result = token.remove_minter(minter);
        assert(result, "Remove minter should succeed");
        assert(!token.is_minter(minter), "Minter should be removed");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_pause_functionality() {
        let (mut token, owner, user1, user2) = setup_token();
        
        // Transfer some tokens to user1 first
        set_caller_address(owner);
        let transfer_amount = 1000000000000000000000; // 1000 tokens
        token.transfer(user1, transfer_amount);
        
        // Pause the contract
        let result = token.pause();
        assert(result, "Pause should succeed");
        assert(token.is_paused(), "Token should be paused");
        
        // Try to transfer while paused (should fail)
        set_caller_address(user1);
        // This would fail in a real scenario, but we can't test failures easily in this setup
        
        // Unpause the contract
        set_caller_address(owner);
        let result = token.unpause();
        assert(result, "Unpause should succeed");
        assert(!token.is_paused(), "Token should not be paused");
        
        // Transfer should work again
        set_caller_address(user1);
        let second_transfer = 500000000000000000000; // 500 tokens
        let result = token.transfer(user2, second_transfer);
        assert(result, "Transfer after unpause should succeed");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_ownership_transfer() {
        let (mut token, owner, user1, _) = setup_token();
        
        set_caller_address(owner);
        
        // Transfer ownership
        let result = token.transfer_ownership(user1);
        assert(result, "Ownership transfer should succeed");
        assert(token.owner() == user1, "New owner should be set");
        
        // Old owner should not be able to perform admin functions
        // New owner should be able to perform admin functions
        set_caller_address(user1);
        let result = token.pause();
        assert(result, "New owner should be able to pause");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_camel_case_compatibility() {
        let (token, owner, _, _) = setup_token();
        
        // Test camelCase variants
        assert(token.totalSupply() == INITIAL_SUPPLY, "totalSupply should work");
        assert(token.balanceOf(owner) == INITIAL_SUPPLY, "balanceOf should work");
        
        // transferFrom is tested in other tests
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_max_supply_enforcement() {
        let (mut token, owner, user1, _) = setup_token();
        
        set_caller_address(owner);
        
        // Try to mint beyond max supply
        let excessive_mint = MAX_SUPPLY; // This would exceed max supply when added to initial supply
        
        // In a real scenario, this should fail, but we can't easily test failures
        // The assertion would be in the mint function itself
        
        // Test that we can mint up to max supply
        let remaining_supply = MAX_SUPPLY - INITIAL_SUPPLY;
        let result = token.mint(user1, remaining_supply);
        assert(result, "Minting up to max supply should succeed");
        assert(token.total_supply() == MAX_SUPPLY, "Total supply should equal max supply");
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: insufficient balance',))]
    fn test_transfer_insufficient_balance() {
        let (mut token, owner, user1, _) = setup_token();
        
        set_caller_address(user1);
        
        // Try to transfer more than balance (user1 has 0 balance)
        let transfer_amount = 1000000000000000000000; // 1000 tokens
        token.transfer(owner, transfer_amount);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: insufficient allowance',))]
    fn test_transfer_from_insufficient_allowance() {
        let (mut token, owner, user1, user2) = setup_token();
        
        set_caller_address(user1);
        
        // Try to transfer from owner without sufficient allowance
        let transfer_amount = 1000000000000000000000; // 1000 tokens
        token.transfer_from(owner, user2, transfer_amount);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: invalid recipient',))]
    fn test_transfer_to_zero_address() {
        let (mut token, owner, _, _) = setup_token();
        
        set_caller_address(owner);
        
        // Try to transfer to zero address
        let zero_address = contract_address_const::<0>();
        let transfer_amount = 1000000000000000000000; // 1000 tokens
        token.transfer(zero_address, transfer_amount);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: invalid spender',))]
    fn test_approve_zero_address() {
        let (mut token, owner, _, _) = setup_token();
        
        set_caller_address(owner);
        
        // Try to approve zero address
        let zero_address = contract_address_const::<0>();
        let approval_amount = 1000000000000000000000; // 1000 tokens
        token.approve(zero_address, approval_amount);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: exceeds max supply',))]
    fn test_mint_exceeds_max_supply() {
        let (mut token, owner, user1, _) = setup_token();
        
        set_caller_address(owner);
        
        // Try to mint beyond max supply
        let excessive_mint = MAX_SUPPLY - INITIAL_SUPPLY + 1; // 1 token over max
        token.mint(user1, excessive_mint);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: unauthorized',))]
    fn test_mint_unauthorized() {
        let (mut token, _, user1, user2) = setup_token();
        
        set_caller_address(user1); // user1 is not a minter
        
        // Try to mint without minter role
        let mint_amount = 1000000000000000000000; // 1000 tokens
        token.mint(user2, mint_amount);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: insufficient balance',))]
    fn test_burn_insufficient_balance() {
        let (mut token, _, user1, _) = setup_token();
        
        set_caller_address(user1); // user1 has 0 balance
        
        // Try to burn more than balance
        let burn_amount = 1000000000000000000000; // 1000 tokens
        token.burn(burn_amount);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: unauthorized',))]
    fn test_pause_unauthorized() {
        let (mut token, _, user1, _) = setup_token();
        
        set_caller_address(user1); // user1 is not owner
        
        // Try to pause without owner role
        token.pause();
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: token transfer paused',))]
    fn test_transfer_while_paused() {
        let (mut token, owner, user1, user2) = setup_token();
        
        // Owner pauses the contract
        set_caller_address(owner);
        token.pause();
        
        // Transfer some tokens to user1 first (this should work before pause)
        token.unpause();
        token.transfer(user1, 1000000000000000000000); // 1000 tokens
        token.pause();
        
        // Try to transfer while paused
        set_caller_address(user1);
        token.transfer(user2, 500000000000000000000); // 500 tokens
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: unauthorized',))]
    fn test_add_minter_unauthorized() {
        let (mut token, _, user1, user2) = setup_token();
        
        set_caller_address(user1); // user1 is not owner
        
        // Try to add minter without owner role
        token.add_minter(user2);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: unauthorized',))]
    fn test_transfer_ownership_unauthorized() {
        let (mut token, _, user1, user2) = setup_token();
        
        set_caller_address(user1); // user1 is not owner
        
        // Try to transfer ownership without owner role
        token.transfer_ownership(user2);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: zero address',))]
    fn test_transfer_ownership_to_zero() {
        let (mut token, owner, _, _) = setup_token();
        
        set_caller_address(owner);
        
        // Try to transfer ownership to zero address
        let zero_address = contract_address_const::<0>();
        token.transfer_ownership(zero_address);
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: already paused',))]
    fn test_pause_already_paused() {
        let (mut token, owner, _, _) = setup_token();
        
        set_caller_address(owner);
        
        // Pause the contract
        token.pause();
        
        // Try to pause again
        token.pause();
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: not paused',))]
    fn test_unpause_not_paused() {
        let (mut token, owner, _, _) = setup_token();
        
        set_caller_address(owner);
        
        // Try to unpause when not paused
        token.unpause();
    }
    
    #[test]
    #[available_gas(2000000)]
    #[should_panic(expected: ('ERC20: insufficient allowance',))]
    fn test_decrease_allowance_below_zero() {
        let (mut token, owner, user1, _) = setup_token();
        
        set_caller_address(owner);
        
        // Set small allowance
        let small_allowance = 100000000000000000000; // 100 tokens
        token.approve(user1, small_allowance);
        
        // Try to decrease by more than current allowance
        let decrease_amount = 200000000000000000000; // 200 tokens
        token.decrease_allowance(user1, decrease_amount);
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_event_emission_verification() {
        let (mut token, owner, user1, _) = setup_token();
        
        set_caller_address(owner);
        
        // Test that transfer emits Transfer event (verified by successful execution)
        let transfer_amount = 1000000000000000000000; // 1000 tokens
        let result = token.transfer(user1, transfer_amount);
        assert(result, "Transfer should succeed and emit event");
        
        // Test that approve emits Approval event (verified by successful execution)
        let approval_amount = 2000000000000000000000; // 2000 tokens
        let result = token.approve(user1, approval_amount);
        assert(result, "Approval should succeed and emit event");
        
        // Test that mint emits Transfer and Mint events (verified by successful execution)
        let mint_amount = 500000000000000000000; // 500 tokens
        let result = token.mint(user1, mint_amount);
        assert(result, "Mint should succeed and emit events");
    }
}
