// interfaces/i_pausable.cairo
#[starknet::interface]
trait IPausable<TContractState> {
    fn is_paused(self: @TContractState) -> bool;
    fn is_function_paused(self: @TContractState, selector: felt252) -> bool;
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn pause_function(ref self: TContractState, selector: felt252);
    fn unpause_function(ref self: TContractState, selector: felt252);
}


// // interfaces/i_pausable.cairo
// #[starknet::interface]
// pub trait IPausable<TContractState> {
//     fn is_paused(self: @TContractState) -> bool;
//     fn is_function_paused(self: @TContractState, selector: felt252) -> bool;
//     fn pause(ref self: TContractState);
//     fn unpause(ref self: TContractState);
//     fn pause_function(ref self: TContractState, selector: felt252);
//     fn unpause_function(ref self: TContractState, selector: felt252);
// }