#[cfg(test)]
mod test_secure_random {
    use starknet::{
        ContractAddress, 
        contract_address_const, 
        testing::{set_caller_address, set_block_timestamp}
    };
    
    use crate::utils::secure_random::{SecureRandom, ISecureRandom};
    use crate::interfaces::i_secure_random::{
        RandomnessRequest, VRFProof, CommitmentScheme,
        ENTROPY_BLOCK_HASH, ENTROPY_TIMESTAMP
    };
    use array::ArrayTrait;

    fn setup_secure_random() -> (ISecureRandom, ContractAddress, ContractAddress) {
        let admin = contract_address_const::<0x123>();
        let user = contract_address_const::<0x456>();
        let access_control = contract_address_const::<0x789>();
        let security_monitor = contract_address_const::<0xabc>();
        
        set_caller_address(admin);
        
        let secure_random = SecureRandom::deploy(
            admin,
            access_control,
            security_monitor
        ).unwrap();
        
        (secure_random, admin, user)
    }

    #[test]
    #[available_gas(5000000)]
    fn test_generate_secure_random() {
        let (secure_random, admin, user) = setup_secure_random();
        
        set_caller_address(user);
        set_block_timestamp(1000);
        
        let random_value = secure_random.generate_secure_random(
            3, // entropy requirement
            'TEST_PURPOSE'
        );
        
        assert(random_value != 0, "Random value should not be zero");
        
        // Generate another random value and ensure it's different
        let random_value2 = secure_random.generate_secure_random(
            3,
            'TEST_PURPOSE_2'
        );
        
        assert(random_value != random_value2, "Random values should be different");
    }

    #[test]
    #[available_gas(5000000)]
    fn test_vrf_proof_creation_and_verification() {
        let (secure_random, admin, user) = setup_secure_random();
        
        set_caller_address(admin); // Admin has VRF_GENERATOR role
        
        let public_key = 'test_public_key';
        let input = 'test_input';
        let private_key = 'test_private_key';
        
        let proof_id = secure_random.create_vrf_proof(
            public_key,
            input,
            private_key
        );
        
        assert(proof_id != 0, "Proof ID should be generated");
        
        let is_valid = secure_random.verify_vrf_proof(proof_id);
        assert(is_valid, "VRF proof should be valid");
    }

    #[test]
    #[available_gas(5000000)]
    fn test_commitment_scheme() {
        let (secure_random, admin, user) = setup_secure_random();
        
        set_caller_address(user);
        set_block_timestamp(1000);
        
        let value = 'secret_value';
        let nonce = 'random_nonce';
        
        // Create commitment
        let commitment_id = secure_random.create_commitment(value, nonce);
        assert(commitment_id != 0, "Commitment ID should be generated");
        
        // Reveal commitment
        set_block_timestamp(1500); // Within reveal window
        let is_valid = secure_random.reveal_commitment(
            commitment_id,
            value,
            nonce
        );
        
        assert(is_valid, "Commitment should be valid when revealed correctly");
    }

    #[test]
    #[available_gas(5000000)]
    fn test_entropy_pool_status() {
        let (secure_random, admin, user) = setup_secure_random();
        
        let (counter, sources, last_refresh) = secure_random.get_entropy_pool_status();
        
        assert(sources >= 3, "Should have at least 3 entropy sources");
        assert(last_refresh > 0, "Should have refresh timestamp");
    }

    #[test]
    #[available_gas(5000000)]
    fn test_multiple_entropy_sources() {
        let (secure_random, admin, user) = setup_secure_random();
        
        set_caller_address(user);
        
        // Test with different entropy requirements
        let random1 = secure_random.generate_secure_random(3, 'TEST_1');
        let random2 = secure_random.generate_secure_random(4, 'TEST_2');
        
        assert(random1 != random2, "Different entropy should produce different results");
    }

    #[test]
    #[available_gas(5000000)]
    #[should_panic(expected: ('Insufficient entropy sources',))]
    fn test_insufficient_entropy_sources() {
        let (secure_random, admin, user) = setup_secure_random();
        
        set_caller_address(user);
        
        // Try to request more entropy sources than available
        secure_random.generate_secure_random(10, 'TEST_FAIL');
    }

    #[test]
    #[available_gas(5000000)]
    #[should_panic(expected: ('Reveal deadline passed',))]
    fn test_commitment_deadline_expired() {
        let (secure_random, admin, user) = setup_secure_random();
        
        set_caller_address(user);
        set_block_timestamp(1000);
        
        let value = 'secret_value';
        let nonce = 'random_nonce';
        
        let commitment_id = secure_random.create_commitment(value, nonce);
        
        // Try to reveal after deadline (30 minutes + buffer)
        set_block_timestamp(3000);
        secure_random.reveal_commitment(commitment_id, value, nonce);
    }
}