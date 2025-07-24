// Enhanced Cryptographic Utilities for StarkPulse
#[starknet::contract]
mod CryptoUtils {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::Map;
    use array::ArrayTrait;
    use pedersen::pedersen;
    use crate::interfaces::i_crypto_utils::{
        ICryptoUtils, HashChain, MerkleProof, NonceManager,
        HASH_CHAIN_GENESIS, MERKLE_TREE_MAX_DEPTH
    };

    #[storage]
    struct Storage {
        // Hash chain implementation
        hash_chains: Map<felt252, HashChain>,
        chain_counter: u64,
        
        // Merkle proof system
        merkle_roots: Map<felt252, felt252>,
        merkle_proofs: Map<felt252, MerkleProof>,
        
        // Nonce management
        nonce_managers: Map<ContractAddress, NonceManager>,
        global_nonce: u256,
        
        // Commitment tracking
        commitment_registry: Map<felt252, bool>,
    }

    #[external(v0)]
    impl CryptoUtilsImpl of ICryptoUtils<ContractState> {
        fn create_hash_chain(
            ref self: ContractState,
            initial_data: felt252
        ) -> felt252 {
            let chain_id = self._generate_chain_id();
            let genesis_hash = pedersen(HASH_CHAIN_GENESIS, initial_data);
            
            let hash_chain = HashChain {
                chain_id: chain_id,
                genesis_hash: genesis_hash,
                current_hash: genesis_hash,
                length: 1,
                created_at: get_block_timestamp(),
                last_updated: get_block_timestamp(),
            };
            
            self.hash_chains.write(chain_id, hash_chain);
            chain_id
        }

        fn extend_hash_chain(
            ref self: ContractState,
            chain_id: felt252,
            new_data: felt252
        ) -> felt252 {
            let mut chain = self.hash_chains.read(chain_id);
            let new_hash = pedersen(chain.current_hash, new_data);
            
            chain.current_hash = new_hash;
            chain.length += 1;
            chain.last_updated = get_block_timestamp();
            
            self.hash_chains.write(chain_id, chain);
            new_hash
        }

        fn verify_hash_chain(
            self: @ContractState,
            chain_id: felt252,
            claimed_hash: felt252
        ) -> bool {
            let chain = self.hash_chains.read(chain_id);
            chain.current_hash == claimed_hash
        }

        fn generate_secure_nonce(
            ref self: ContractState,
            user: ContractAddress
        ) -> felt252 {
            let mut nonce_manager = self.nonce_managers.read(user);
            nonce_manager.current_nonce += 1;
            nonce_manager.last_used = get_block_timestamp();
            
            self.nonce_managers.write(user, nonce_manager);
            
            // Combine user nonce with global entropy
            let global_nonce = self.global_nonce.read();
            self.global_nonce.write(global_nonce + 1);
            
            pedersen(
                nonce_manager.current_nonce.into(),
                pedersen(user.into(), global_nonce.into())
            )
        }

        fn create_merkle_proof(
            ref self: ContractState,
            leaf: felt252,
            siblings: Array<felt252>
        ) -> felt252 {
            assert(siblings.len() <= MERKLE_TREE_MAX_DEPTH, 'Proof too deep');
            
            let proof_id = self._generate_proof_id();
            let root = self._compute_merkle_root(leaf, siblings.span());
            
            let merkle_proof = MerkleProof {
                proof_id: proof_id,
                leaf: leaf,
                root: root,
                siblings: siblings,
                verified: false,
                created_at: get_block_timestamp(),
            };
            
            self.merkle_proofs.write(proof_id, merkle_proof);
            self.merkle_roots.write(proof_id, root);
            
            proof_id
        }

        fn verify_merkle_proof(
            ref self: ContractState,
            proof_id: felt252
        ) -> bool {
            let mut proof = self.merkle_proofs.read(proof_id);
            let computed_root = self._compute_merkle_root(proof.leaf, proof.siblings.span());
            
            let is_valid = computed_root == proof.root;
            proof.verified = is_valid;
            self.merkle_proofs.write(proof_id, proof);
            
            is_valid
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _compute_merkle_root(
            self: @ContractState,
            leaf: felt252,
            siblings: Span<felt252>
        ) -> felt252 {
            let mut current_hash = leaf;
            let mut i = 0;
            
            while i < siblings.len() {
                let sibling = *siblings.at(i);
                current_hash = if current_hash < sibling {
                    pedersen(current_hash, sibling)
                } else {
                    pedersen(sibling, current_hash)
                };
                i += 1;
            };
            
            current_hash
        }

        fn _generate_chain_id(ref self: ContractState) -> felt252 {
            let counter = self.chain_counter.read();
            self.chain_counter.write(counter + 1);
            
            let timestamp = get_block_timestamp();
            pedersen(counter.into(), timestamp.into())
        }

        fn _generate_proof_id(self: @ContractState) -> felt252 {
            let timestamp = get_block_timestamp();
            let caller = get_caller_address();
            pedersen(timestamp.into(), caller.into())
        }
    }
}
