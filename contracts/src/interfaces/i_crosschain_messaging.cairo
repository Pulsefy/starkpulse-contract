// Interface for Cross-Chain Messaging
%lang starknet

@contract_interface
trait ICrossChainMessaging {
    fn send_message(to_chain: felt252, payload: felt252*) -> felt252;
    fn receive_message(from_chain: felt252, payload: felt252*) -> felt252;
}
