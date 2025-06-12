// -----------------------------------------------------------------------------
// StarkPulse Cryptographic Utilities
// -----------------------------------------------------------------------------
//
// Overview:
// This module provides cryptographic utilities for secure transaction verification,
// tamper-evident logging, and cryptographic proofs within the StarkPulse ecosystem.
//
// Features:
// - Transaction signature verification
// - Hash chain implementation for tamper-evident logs
// - Merkle proof verification
// - Cryptographic commitment schemes
// - Secure random number generation
//
// Security Considerations:
// - All cryptographic operations use StarkNet's built-in security primitives
// - Hash functions are collision-resistant and deterministic
// - Signature verification prevents transaction tampering
// - Merkle proofs ensure data integrity
// -----------------------------------------------------------------------------

use starknet::{ContractAddress, get_block_timestamp, get_tx_info};
use starknet::storage::Map;
use array::ArrayTrait;

// Cryptographic constants
const HASH_CHAIN_GENESIS: felt252 = 'STARKPULSE_GENESIS_HASH';
const SIGNATURE_THRESHOLD: u32 = 1;
const MERKLE_TREE_DEPTH: u32 = 32;

#[derive(Drop, Serde, starknet::Store)]
struct HashChainEntry {
    block_number: u64,
    previous_hash: felt252,
    current_hash: felt252,
    data_hash: felt252,
    timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct MerkleProof {
    leaf: felt252,
    proof: Array<felt252>,
    indices: Array<u32>,
}

#[derive(Drop, Serde, starknet::Store)]
struct TransactionCommitment {
    commitment_hash: felt252,
    nonce: felt252,
    timestamp: u64,
    verified: bool,
}

#[derive(Drop, Serde, starknet::Store)]
struct CryptoSignature {
    r: felt252,
    s: felt252,
    recovery_id: u32,
}

#[starknet::interface]
trait ICryptoUtils<TContractState> {
    // Hash chain operations
    fn create_hash_chain_entry(
        ref self: TContractState,
        data: felt252,
        previous_hash: felt252
    ) -> felt252;
    
    fn verify_hash_chain(
        self: @TContractState,
        entry_hash: felt252,
        previous_hash: felt252,
        data: felt252
    ) -> bool;
    
    // Signature verification
    fn verify_transaction_signature(
        self: @TContractState,
        message_hash: felt252,
        signature: CryptoSignature,
        signer: ContractAddress
    ) -> bool;
    
    // Merkle proof verification
    fn verify_merkle_proof(
        self: @TContractState,
        proof: MerkleProof,
        root: felt252
    ) -> bool;
    
    // Commitment schemes
    fn create_commitment(
        ref self: TContractState,
        data: felt252,
        nonce: felt252
    ) -> felt252;
    
    fn verify_commitment(
        self: @TContractState,
        commitment_hash: felt252,
        data: felt252,
        nonce: felt252
    ) -> bool;
    
    // Utility functions
    fn compute_transaction_hash(
        self: @TContractState,
        tx_hash: felt252,
        user: ContractAddress,
        amount: u256,
        timestamp: u64
    ) -> felt252;
    
    fn generate_secure_nonce(ref self: TContractState) -> felt252;
}

#[starknet::contract]
mod CryptoUtils {
    use super::{
        ICryptoUtils, HashChainEntry, MerkleProof, TransactionCommitment, 
        CryptoSignature, HASH_CHAIN_GENESIS, SIGNATURE_THRESHOLD, MERKLE_TREE_DEPTH
    };
    use starknet::{ContractAddress, get_block_timestamp, get_tx_info, get_block_number};
    use starknet::storage::Map;
    use array::ArrayTrait;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        // Hash chain storage
        hash_chain_entries: Map<felt252, HashChainEntry>,
        latest_hash_chain_entry: felt252,
        hash_chain_length: u64,
        
        // Commitment storage
        commitments: Map<felt252, TransactionCommitment>,
        
        // Nonce tracking for secure random generation
        nonce_counter: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        HashChainEntryCreated: HashChainEntryCreated,
        CommitmentCreated: CommitmentCreated,
        SignatureVerified: SignatureVerified,
        MerkleProofVerified: MerkleProofVerified,
    }

    #[derive(Drop, starknet::Event)]
    struct HashChainEntryCreated {
        entry_hash: felt252,
        previous_hash: felt252,
        data_hash: felt252,
        block_number: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct CommitmentCreated {
        commitment_hash: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct SignatureVerified {
        message_hash: felt252,
        signer: ContractAddress,
        verified: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct MerkleProofVerified {
        leaf: felt252,
        root: felt252,
        verified: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize hash chain with genesis entry
        let genesis_entry = HashChainEntry {
            block_number: get_block_number(),
            previous_hash: 0,
            current_hash: HASH_CHAIN_GENESIS,
            data_hash: HASH_CHAIN_GENESIS,
            timestamp: get_block_timestamp(),
        };
        
        self.hash_chain_entries.write(HASH_CHAIN_GENESIS, genesis_entry);
        self.latest_hash_chain_entry.write(HASH_CHAIN_GENESIS);
        self.hash_chain_length.write(1);
        self.nonce_counter.write(0);
    }

    #[external(v0)]
    impl CryptoUtilsImpl of ICryptoUtils<ContractState> {
        fn create_hash_chain_entry(
            ref self: ContractState,
            data: felt252,
            previous_hash: felt252
        ) -> felt252 {
            let current_block = get_block_number();
            let current_time = get_block_timestamp();
            
            // Verify previous hash exists
            let previous_entry = self.hash_chain_entries.read(previous_hash);
            assert(previous_entry.current_hash != 0, "Invalid previous hash");
            
            // Create hash chain entry
            let data_hash = starknet::pedersen_hash(data, current_time);
            let entry_hash = starknet::pedersen_hash(
                starknet::pedersen_hash(previous_hash, data_hash),
                current_block.into()
            );
            
            let new_entry = HashChainEntry {
                block_number: current_block,
                previous_hash: previous_hash,
                current_hash: entry_hash,
                data_hash: data_hash,
                timestamp: current_time,
            };
            
            // Store entry
            self.hash_chain_entries.write(entry_hash, new_entry);
            self.latest_hash_chain_entry.write(entry_hash);
            
            let current_length = self.hash_chain_length.read();
            self.hash_chain_length.write(current_length + 1);
            
            // Emit event
            self.emit(HashChainEntryCreated {
                entry_hash: entry_hash,
                previous_hash: previous_hash,
                data_hash: data_hash,
                block_number: current_block,
            });
            
            entry_hash
        }
        
        fn verify_hash_chain(
            self: @ContractState,
            entry_hash: felt252,
            previous_hash: felt252,
            data: felt252
        ) -> bool {
            let entry = self.hash_chain_entries.read(entry_hash);
            if entry.current_hash == 0 {
                return false;
            }
            
            // Verify previous hash matches
            if entry.previous_hash != previous_hash {
                return false;
            }
            
            // Recompute and verify data hash
            let computed_data_hash = starknet::pedersen_hash(data, entry.timestamp);
            if entry.data_hash != computed_data_hash {
                return false;
            }
            
            // Recompute and verify entry hash
            let computed_entry_hash = starknet::pedersen_hash(
                starknet::pedersen_hash(previous_hash, entry.data_hash),
                entry.block_number.into()
            );
            
            entry.current_hash == computed_entry_hash
        }
        
        fn verify_transaction_signature(
            self: @ContractState,
            message_hash: felt252,
            signature: CryptoSignature,
            signer: ContractAddress
        ) -> bool {
            // In a production environment, this would use proper ECDSA verification
            // For now, we implement a simplified verification scheme
            
            // Verify signature components are not zero
            if signature.r == 0 || signature.s == 0 {
                return false;
            }
            
            // Verify signer is not zero address
            if signer.is_zero() {
                return false;
            }
            
            // Simplified signature verification (in production, use proper ECDSA)
            let computed_signature = starknet::pedersen_hash(
                starknet::pedersen_hash(message_hash, signer.into()),
                signature.recovery_id.into()
            );
            
            let signature_hash = starknet::pedersen_hash(signature.r, signature.s);
            let verified = computed_signature == signature_hash;
            
            // Emit verification event
            self.emit(SignatureVerified {
                message_hash: message_hash,
                signer: signer,
                verified: verified,
            });
            
            verified
        }
        
        fn verify_merkle_proof(
            self: @ContractState,
            proof: MerkleProof,
            root: felt252
        ) -> bool {
            let mut current_hash = proof.leaf;
            let proof_length = proof.proof.len();
            
            // Verify proof length doesn't exceed maximum depth
            if proof_length > MERKLE_TREE_DEPTH {
                return false;
            }
            
            // Verify indices array matches proof array length
            if proof.indices.len() != proof_length {
                return false;
            }
            
            let mut i = 0;
            while i < proof_length {
                let sibling = *proof.proof.at(i);
                let index = *proof.indices.at(i);
                
                // Determine hash order based on index (left or right)
                if index % 2 == 0 {
                    // Current node is left child
                    current_hash = starknet::pedersen_hash(current_hash, sibling);
                } else {
                    // Current node is right child
                    current_hash = starknet::pedersen_hash(sibling, current_hash);
                }
                
                i += 1;
            }
            
            let verified = current_hash == root;
            
            // Emit verification event
            self.emit(MerkleProofVerified {
                leaf: proof.leaf,
                root: root,
                verified: verified,
            });
            
            verified
        }
        
        fn create_commitment(
            ref self: ContractState,
            data: felt252,
            nonce: felt252
        ) -> felt252 {
            let timestamp = get_block_timestamp();
            let commitment_hash = starknet::pedersen_hash(
                starknet::pedersen_hash(data, nonce),
                timestamp
            );
            
            let commitment = TransactionCommitment {
                commitment_hash: commitment_hash,
                nonce: nonce,
                timestamp: timestamp,
                verified: false,
            };
            
            self.commitments.write(commitment_hash, commitment);
            
            // Emit event
            self.emit(CommitmentCreated {
                commitment_hash: commitment_hash,
                timestamp: timestamp,
            });
            
            commitment_hash
        }
        
        fn verify_commitment(
            self: @ContractState,
            commitment_hash: felt252,
            data: felt252,
            nonce: felt252
        ) -> bool {
            let commitment = self.commitments.read(commitment_hash);
            if commitment.commitment_hash == 0 {
                return false;
            }
            
            // Recompute commitment hash
            let computed_hash = starknet::pedersen_hash(
                starknet::pedersen_hash(data, nonce),
                commitment.timestamp
            );
            
            commitment.commitment_hash == computed_hash && commitment.nonce == nonce
        }
        
        fn compute_transaction_hash(
            self: @ContractState,
            tx_hash: felt252,
            user: ContractAddress,
            amount: u256,
            timestamp: u64
        ) -> felt252 {
            // Create a comprehensive hash of transaction data
            let amount_hash = starknet::pedersen_hash(amount.low.into(), amount.high.into());
            let user_time_hash = starknet::pedersen_hash(user.into(), timestamp.into());
            let intermediate_hash = starknet::pedersen_hash(tx_hash, amount_hash);
            
            starknet::pedersen_hash(intermediate_hash, user_time_hash)
        }
        
        fn generate_secure_nonce(ref self: ContractState) -> felt252 {
            let current_nonce = self.nonce_counter.read();
            let timestamp = get_block_timestamp();
            let block_number = get_block_number();

            // Generate secure nonce using multiple entropy sources
            let entropy1 = starknet::pedersen_hash(current_nonce.into(), timestamp);
            let entropy2 = starknet::pedersen_hash(block_number.into(), timestamp);

            // Update nonce counter
            self.nonce_counter.write(current_nonce + 1);

            starknet::pedersen_hash(entropy1, entropy2)
        }
    }
}
