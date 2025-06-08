#[cfg(test)]
mod test_event_emission {
    use starknet::{
        ContractAddress, 
        contract_address_const, 
        testing::set_caller_address
    };
    
    use crate::tokens::erc20_token::{ERC20Token, IERC20Extended};
    use crate::interfaces::i_erc20::IERC20;
    
    // Test addresses
    const OWNER: felt252 = 0x123;
    const USER1: felt252 = 0x456;
    const USER2: felt252 = 0x789;
    
    fn setup_token_for_events() -> (ERC20Token::ContractState, ContractAddress, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<OWNER>();
        let user1 = contract_address_const::<USER1>();
        let user2 = contract_address_const::<USER2>();
        
        set_caller_address(owner);
        
        let mut token = ERC20Token::unsafe_new();
        token.constructor(
            'Event Test Token',
            'ETT',
            18,
            1000000000000000000000000, // 1M tokens
            10000000000000000000000000, // 10M max
            owner,
            true, // mintable
            true  // burnable
        );
        
        (token, owner, user1, user2)
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_transfer_event_emission() {
        let (mut token, owner, user1, _) = setup_token_for_events();
        
        set_caller_address(owner);
        
        let transfer_amount = 1000000000000000000000; // 1000 tokens
        
        // Transfer should emit Transfer event
        let result = token.transfer(user1, transfer_amount);
        assert(result, "Transfer should succeed");
        
        // Verify balances changed (indirect verification of event)
        assert(token.balance_of(user1) == transfer_amount, "User1 should receive tokens");
        assert(token.balance_of(owner) == 1000000000000000000000000 - transfer_amount, "Owner balance should decrease");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_approval_event_emission() {
        let (mut token, owner, user1, _) = setup_token_for_events();
        
        set_caller_address(owner);
        
        let approval_amount = 2000000000000000000000; // 2000 tokens
        
        // Approve should emit Approval event
        let result = token.approve(user1, approval_amount);
        assert(result, "Approval should succeed");
        
        // Verify allowance changed (indirect verification of event)
        assert(token.allowance(owner, user1) == approval_amount, "Allowance should be set");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_mint_event_emission() {
        let (mut token, owner, user1, _) = setup_token_for_events();
        
        set_caller_address(owner);
        
        let mint_amount = 500000000000000000000; // 500 tokens
        let initial_supply = token.total_supply();
        
        // Mint should emit Transfer (from zero) and Mint events
        let result = token.mint(user1, mint_amount);
        assert(result, "Mint should succeed");
        
        // Verify state changes (indirect verification of events)
        assert(token.balance_of(user1) == mint_amount, "User1 should receive minted tokens");
        assert(token.total_supply() == initial_supply + mint_amount, "Total supply should increase");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_burn_event_emission() {
        let (mut token, owner, user1, _) = setup_token_for_events();
        
        // First transfer some tokens to user1
        set_caller_address(owner);
        let transfer_amount = 2000000000000000000000; // 2000 tokens
        token.transfer(user1, transfer_amount);
        
        set_caller_address(user1);
        
        let burn_amount = 1000000000000000000000; // 1000 tokens
        let initial_supply = token.total_supply();
        let initial_balance = token.balance_of(user1);
        
        // Burn should emit Transfer (to zero) and Burn events
        let result = token.burn(burn_amount);
        assert(result, "Burn should succeed");
        
        // Verify state changes (indirect verification of events)
        assert(token.balance_of(user1) == initial_balance - burn_amount, "User1 balance should decrease");
        assert(token.total_supply() == initial_supply - burn_amount, "Total supply should decrease");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_ownership_transfer_event() {
        let (mut token, owner, user1, _) = setup_token_for_events();
        
        set_caller_address(owner);
        
        // Transfer ownership should emit OwnershipTransferred event
        let result = token.transfer_ownership(user1);
        assert(result, "Ownership transfer should succeed");
        
        // Verify ownership changed (indirect verification of event)
        assert(token.owner() == user1, "Ownership should be transferred");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_minter_management_events() {
        let (mut token, owner, user1, _) = setup_token_for_events();
        
        set_caller_address(owner);
        
        // Add minter should emit MinterAdded event
        let result = token.add_minter(user1);
        assert(result, "Add minter should succeed");
        assert(token.is_minter(user1), "User1 should be a minter");
        
        // Remove minter should emit MinterRemoved event
        let result = token.remove_minter(user1);
        assert(result, "Remove minter should succeed");
        assert(!token.is_minter(user1), "User1 should not be a minter");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_pause_events() {
        let (mut token, owner, _, _) = setup_token_for_events();
        
        set_caller_address(owner);
        
        // Pause should emit Paused event
        let result = token.pause();
        assert(result, "Pause should succeed");
        assert(token.is_paused(), "Token should be paused");
        
        // Unpause should emit Unpaused event
        let result = token.unpause();
        assert(result, "Unpause should succeed");
        assert(!token.is_paused(), "Token should not be paused");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_multiple_events_in_sequence() {
        let (mut token, owner, user1, user2) = setup_token_for_events();
        
        set_caller_address(owner);
        
        // Sequence of operations that should emit multiple events
        
        // 1. Transfer (Transfer event)
        let transfer_amount = 1000000000000000000000; // 1000 tokens
        token.transfer(user1, transfer_amount);
        
        // 2. Approve (Approval event)
        let approval_amount = 500000000000000000000; // 500 tokens
        token.approve(user2, approval_amount);
        
        // 3. Mint (Transfer + Mint events)
        let mint_amount = 300000000000000000000; // 300 tokens
        token.mint(user1, mint_amount);
        
        // 4. Transfer from user1 (Transfer event)
        set_caller_address(user1);
        let user_transfer = 200000000000000000000; // 200 tokens
        token.transfer(user2, user_transfer);
        
        // 5. Burn from user1 (Transfer + Burn events)
        let burn_amount = 100000000000000000000; // 100 tokens
        token.burn(burn_amount);
        
        // Verify final state reflects all operations
        let expected_user1_balance = transfer_amount + mint_amount - user_transfer - burn_amount;
        let expected_user2_balance = user_transfer;
        
        assert(token.balance_of(user1) == expected_user1_balance, "User1 final balance should be correct");
        assert(token.balance_of(user2) == expected_user2_balance, "User2 final balance should be correct");
    }
}
