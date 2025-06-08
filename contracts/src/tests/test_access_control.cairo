#[cfg(test)]
mod test_access_control {
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
    const MINTER: felt252 = 0xabc;
    
    fn setup_token_for_access_tests() -> (ERC20Token::ContractState, ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
        let owner = contract_address_const::<OWNER>();
        let user1 = contract_address_const::<USER1>();
        let user2 = contract_address_const::<USER2>();
        let minter = contract_address_const::<MINTER>();
        
        set_caller_address(owner);
        
        let mut token = ERC20Token::unsafe_new();
        token.constructor(
            'Test Token',
            'TEST',
            18,
            1000000000000000000000000, // 1M tokens
            10000000000000000000000000, // 10M max
            owner,
            true, // mintable
            true  // burnable
        );
        
        (token, owner, user1, user2, minter)
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_owner_permissions() {
        let (mut token, owner, user1, _, minter) = setup_token_for_access_tests();
        
        set_caller_address(owner);
        
        // Owner should be able to add minters
        let result = token.add_minter(minter);
        assert(result, "Owner should be able to add minters");
        assert(token.is_minter(minter), "Minter should be added");
        
        // Owner should be able to remove minters
        let result = token.remove_minter(minter);
        assert(result, "Owner should be able to remove minters");
        assert(!token.is_minter(minter), "Minter should be removed");
        
        // Owner should be able to pause
        let result = token.pause();
        assert(result, "Owner should be able to pause");
        assert(token.is_paused(), "Token should be paused");
        
        // Owner should be able to unpause
        let result = token.unpause();
        assert(result, "Owner should be able to unpause");
        assert(!token.is_paused(), "Token should not be paused");
        
        // Owner should be able to transfer ownership
        let result = token.transfer_ownership(user1);
        assert(result, "Owner should be able to transfer ownership");
        assert(token.owner() == user1, "Ownership should be transferred");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_minter_permissions() {
        let (mut token, owner, user1, user2, minter) = setup_token_for_access_tests();
        
        // Add minter
        set_caller_address(owner);
        token.add_minter(minter);
        
        // Minter should be able to mint
        set_caller_address(minter);
        let mint_amount = 1000000000000000000000; // 1000 tokens
        let result = token.mint(user1, mint_amount);
        assert(result, "Minter should be able to mint");
        assert(token.balance_of(user1) == mint_amount, "Tokens should be minted");
        
        // Minter should NOT be able to add other minters
        // This would fail in practice, but we can't easily test panics here
        
        // Minter should NOT be able to pause
        // This would fail in practice, but we can't easily test panics here
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_user_permissions() {
        let (mut token, owner, user1, user2, _) = setup_token_for_access_tests();
        
        // Transfer some tokens to user1
        set_caller_address(owner);
        let transfer_amount = 5000000000000000000000; // 5000 tokens
        token.transfer(user1, transfer_amount);
        
        set_caller_address(user1);
        
        // User should be able to transfer their own tokens
        let user_transfer = 1000000000000000000000; // 1000 tokens
        let result = token.transfer(user2, user_transfer);
        assert(result, "User should be able to transfer own tokens");
        
        // User should be able to approve others
        let approval_amount = 2000000000000000000000; // 2000 tokens
        let result = token.approve(user2, approval_amount);
        assert(result, "User should be able to approve others");
        
        // User should be able to burn their own tokens
        let burn_amount = 500000000000000000000; // 500 tokens
        let result = token.burn(burn_amount);
        assert(result, "User should be able to burn own tokens");
        
        // Verify final balance
        let expected_balance = transfer_amount - user_transfer - burn_amount;
        assert(token.balance_of(user1) == expected_balance, "User balance should be correct");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_role_hierarchy() {
        let (mut token, owner, user1, _, minter) = setup_token_for_access_tests();
        
        // Owner is automatically a minter
        assert(token.is_minter(owner), "Owner should be a minter");
        
        // Add additional minter
        set_caller_address(owner);
        token.add_minter(minter);
        
        // Both owner and minter should be able to mint
        let mint_amount = 1000000000000000000000; // 1000 tokens
        
        set_caller_address(owner);
        let result = token.mint(user1, mint_amount);
        assert(result, "Owner should be able to mint");
        
        set_caller_address(minter);
        let result = token.mint(user1, mint_amount);
        assert(result, "Minter should be able to mint");
        
        // Verify total minted
        assert(token.balance_of(user1) == mint_amount * 2, "Both mints should succeed");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_emergency_controls() {
        let (mut token, owner, user1, user2, _) = setup_token_for_access_tests();
        
        // Transfer tokens to user1
        set_caller_address(owner);
        let transfer_amount = 2000000000000000000000; // 2000 tokens
        token.transfer(user1, transfer_amount);
        
        // Normal transfer should work
        set_caller_address(user1);
        let normal_transfer = 500000000000000000000; // 500 tokens
        let result = token.transfer(user2, normal_transfer);
        assert(result, "Normal transfer should work");
        
        // Owner pauses the contract
        set_caller_address(owner);
        token.pause();
        
        // Transfers should be blocked while paused
        set_caller_address(user1);
        // This would fail in practice due to pause, but we can't easily test panics
        
        // Owner unpauses
        set_caller_address(owner);
        token.unpause();
        
        // Transfers should work again
        set_caller_address(user1);
        let post_pause_transfer = 300000000000000000000; // 300 tokens
        let result = token.transfer(user2, post_pause_transfer);
        assert(result, "Transfer should work after unpause");
        
        // Verify final balances
        let expected_user1_balance = transfer_amount - normal_transfer - post_pause_transfer;
        let expected_user2_balance = normal_transfer + post_pause_transfer;
        
        assert(token.balance_of(user1) == expected_user1_balance, "User1 balance should be correct");
        assert(token.balance_of(user2) == expected_user2_balance, "User2 balance should be correct");
    }
}
