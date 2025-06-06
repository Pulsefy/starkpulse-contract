#[starknet::interface]
trait IPortfolioTracker<TContractState> {
    fn add_asset(ref self: TContractState, asset_address: starknet::ContractAddress, amount: u256) -> bool;
    fn remove_asset(ref self: TContractState, asset_address: starknet::ContractAddress, amount: u256) -> bool;
    fn get_portfolio(self: @TContractState, user_address: starknet::ContractAddress) -> Array<Asset>;
    fn get_portfolio_value(self: @TContractState, user_address: starknet::ContractAddress) -> u256;

    fn batch_add_assets(
        ref self: TContractState,
        asset_addresses: Array<starknet::ContractAddress>,
        amounts: Array<u256>
    ) -> bool;

    fn batch_remove_assets(
        ref self: TContractState,
        asset_addresses: Array<starknet::ContractAddress>,
        amounts: Array<u256>
    ) -> bool;
}

#[derive(Drop, Serde)]
struct Asset {
    address: starknet::ContractAddress,
    amount: u256,
    last_updated: u64,
}