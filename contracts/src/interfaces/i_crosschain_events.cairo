// Interface for Cross-Chain Event Propagation
%lang starknet

@contract_interface
trait ICrossChainEvents {
    fn propagate_event(event_type: felt252, data: felt252*, to_chain: felt252) -> felt252;
}
