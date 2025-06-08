#[cfg(test)]
mod test_starkpulse_token {
    use starknet::{
        ContractAddress, 
        contract_address_const, 
        testing::set_caller_address
    };
    
    use crate::tokens::starkpulse_token::StarkPulseToken;
    use crate::tokens::erc20_token::IERC20Extended;
    use crate::interfaces::i_erc20::IERC20;
    
    // Test addresses
    const OWNER: felt252 = 0x123;
    const USER1: felt252 = 0x456;
    
    #[test]
    #[available_gas(2000000)]
    fn test_starkpulse_token_initialization() {
        let owner = contract_address_const::<OWNER>();
        
        set_caller_address(owner);
        
        let mut token = StarkPulseToken::unsafe_new();
        token.constructor(owner);
        
        // Test StarkPulse specific parameters
        assert(token.name() == 'StarkPulse Token', "Name should be StarkPulse Token");
        assert(token.symbol() == 'SPT', "Symbol should be SPT");
        assert(token.decimals() == 18, "Decimals should be 18");
        assert(token.total_supply() == 100000000000000000000000000, "Initial supply should be 100M tokens");
        assert(token.max_supply() == 1000000000000000000000000000, "Max supply should be 1B tokens");
        
        // Test that owner has initial supply
        assert(token.balance_of(owner) == 100000000000000000000000000, "Owner should have initial supply");
        
        // Test that token is mintable and burnable
        assert(token.is_mintable(), "Token should be mintable");
        assert(token.is_burnable(), "Token should be burnable");
        assert(token.owner() == owner, "Owner should be set correctly");
        assert(token.is_minter(owner), "Owner should be a minter");
    }
    
    #[test]
    #[available_gas(2000000)]
    fn test_starkpulse_token_functionality() {
        let owner = contract_address_const::<OWNER>();
        let user1 = contract_address_const::<USER1>();
        
        set_caller_address(owner);
        
        let mut token = StarkPulseToken::unsafe_new();
        token.constructor(owner);
        
        // Test transfer functionality
        let transfer_amount = 1000000000000000000000; // 1000 SPT
        let result = token.transfer(user1, transfer_amount);
        assert(result, "Transfer should succeed");
        assert(token.balance_of(user1) == transfer_amount, "User1 should receive tokens");
        
        // Test minting functionality
        let mint_amount = 5000000000000000000000; // 5000 SPT
        let result = token.mint(user1, mint_amount);
        assert(result, "Minting should succeed");
        assert(token.balance_of(user1) == transfer_amount + mint_amount, "User1 balance should include minted tokens");
        
        // Test burning functionality
        set_caller_address(user1);
        let burn_amount = 2000000000000000000000; // 2000 SPT
        let result = token.burn(burn_amount);
        assert(result, "Burning should succeed");
        assert(token.balance_of(user1) == transfer_amount + mint_amount - burn_amount, "User1 balance should reflect burned tokens");
    }
}
