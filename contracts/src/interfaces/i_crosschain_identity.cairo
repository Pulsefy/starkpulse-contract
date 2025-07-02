// Interface for Cross-Chain Identity Verification
%lang starknet

@contract_interface
trait ICrossChainIdentity {
    fn verify_identity(user: felt252, chain_id: felt252, proof: felt252*) -> felt252;
}
