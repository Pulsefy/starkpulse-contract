use starknet::ContractAddress;
use starknet::ClassHash;

#[starknet::interface]
pub trait IUpgradeable<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash, new_version: u256);
    fn get_admin(self: @TContractState) -> ContractAddress;
    fn get_version(self: @TContractState) -> u256;
}