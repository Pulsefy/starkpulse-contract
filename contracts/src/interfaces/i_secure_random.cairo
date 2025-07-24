// Interface for Secure Random Number Generation
use starknet::ContractAddress;
use array::Array;

// Entropy source types
const ENTROPY_BLOCK_HASH: u8 = 1;
const ENTROPY_TIMESTAMP: u8 = 2;
const ENTROPY_CALLER: u8 = 3;
const ENTROPY_NONCE: u8 = 4;

// VRF status constants
const VRF_STATUS_PENDING: u8 = 0;
const VRF_STATUS_VERIFIED: u8 = 1;
const VRF_STATUS_INVALID: u8 = 2;

#[derive(Drop, Serde, starknet::Store)]
struct RandomnessRequest {
    request_id: felt252,
    requester: ContractAddress,
    purpose: felt252,
    entropy_requirement: u8,
    timestamp: u64,
    fulfilled: bool,
    random_value: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
struct VRFProof {
    proof_id: felt252,
    public_key: felt252,
    input: felt252,
    output: felt252,
    proof: felt252,
    timestamp: u64,
    status: u8,
    verifier: ContractAddress,
}

#[derive(Drop, Serde, starknet::Store)]
struct CommitmentScheme {
    commitment_id: felt252,
    committer: ContractAddress,
    commitment_hash: felt252,
    created_at: u64,
    reveal_deadline: u64,
    revealed: bool,
    revealed_value: felt252,
    is_valid: bool,
}

#[derive(Drop, Serde, starknet::Store)]
struct EntropySource {
    source_id: u8,
    source_type: felt252,
    weight: u8,
    last_used: u64,
    active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
struct RandomnessAuditLog {
    log_id: felt252,
    operation: felt252,
    caller: ContractAddress,
    details: felt252,
    timestamp: u64,
    block_number: u64,
}

#[starknet::interface]
trait ISecureRandom<TContractState> {
    // Core randomness generation
    fn generate_secure_random(
        ref self: TContractState,
        entropy_requirement: u8,
        purpose: felt252
    ) -> felt252;
    
    // VRF implementation
    fn create_vrf_proof(
        ref self: TContractState,
        public_key: felt252,
        input: felt252,
        private_key: felt252
    ) -> felt252;
    
    fn verify_vrf_proof(
        self: @TContractState,
        proof_id: felt252
    ) -> bool;
    
    // Commitment schemes
    fn create_commitment(
        ref self: TContractState,
        value: felt252,
        nonce: felt252
    ) -> felt252;
    
    fn reveal_commitment(
        ref self: TContractState,
        commitment_id: felt252,
        value: felt252,
        nonce: felt252
    ) -> bool;
    
    // Audit and monitoring
    fn get_randomness_audit_log(
        self: @TContractState,
        log_id: felt252
    ) -> RandomnessAuditLog;
    
    fn get_entropy_pool_status(
        self: @TContractState
    ) -> (u256, u8, u64);
}