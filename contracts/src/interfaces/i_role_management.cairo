// interfaces/i_role_management.cairo
use starknet::ContractAddress;
#[starknet::interface]
trait IRoleManagement<TContractState> {
    fn setup_roles(self: @TContractState);
    fn grant_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn has_role(self: @TContractState, role: felt252, account: ContractAddress) -> bool;
}