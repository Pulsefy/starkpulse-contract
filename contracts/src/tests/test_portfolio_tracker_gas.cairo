#[cfg(test)]
mod test_portfolio_tracker_gas {
    use starknet::{ContractAddress, contract_address_const, get_caller_address, testing::set_caller_address, testing::set_block_timestamp};
    use crate::portfolio::portfolio_tracker::PortfolioTracker;
    use array::ArrayTrait;

    #[test]
    #[available_gas(2000000)]
    fn test_batch_vs_single_gas() {
        let mut tracker = PortfolioTracker::unsafe_new();
        let user = contract_address_const::<0x1>();
        set_caller_address(user);
        set_block_timestamp(1000);

        let mut assets = ArrayTrait::new();
        let mut amounts = ArrayTrait::new();
        let n = 10;
        let amount = 100_u256;
        let mut i = 0;
        while i < n {
            assets.append(contract_address_const::<i as felt252>());
            amounts.append(amount);
            i += 1;
        }

        // Batch add
        tracker.batch_add_assets(assets.clone(), amounts.clone());

        // Single adds
        i = 0;
        while i < n {
            tracker.add_asset(assets.at(i), amounts.at(i));
            i += 1;
        }
    }
}
