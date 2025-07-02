// Interface for Asset Bridge
%lang starknet

@contract_interface
trait IAssetBridge {
    fn lock_asset(asset: felt252, amount: felt252, to_chain: felt252, recipient: felt252) -> felt252;
    fn release_asset(asset: felt252, amount: felt252, from_chain: felt252, sender: felt252) -> felt252;
}
