// Tests for simulation utilities
// ...test cases and scenarios to be implemented...

#[cfg(test)]
mod test_simulation {
    use super::*;
    use contracts::src::simulation::transaction_simulator::{simulate_transaction_full, SimulationReport, SimulationHook};
    use contracts::src::interfaces::i_contract_interaction::IContractInteraction;
    use starknet::{ArrayTrait};

    struct DummyContractInteraction;
    impl IContractInteraction for DummyContractInteraction {
        fn call_contract(&self, contract_name: felt252, function_name: felt252, calldata: Array<felt252>) -> Array<felt252> {
            // Return calldata as result for test
            calldata
        }
    }

    struct NoopHook;
    impl SimulationHook for NoopHook {
        fn run(&self, _contract_name: felt252, _function_name: felt252, _calldata: Array<felt252>) {}
    }

    #[test]
    fn test_simulate_transaction_full_success() {
        let contract = DummyContractInteraction;
        let calldata = ArrayTrait::new();
        let report = simulate_transaction_full(
            contract,
            'TestContract',
            'transfer',
            calldata.clone(),
            Some(NoopHook),
            Some(NoopHook)
        );
        assert(report.result.success, 'Simulation should succeed');
        assert(report.gas_used == 21000, 'Gas used should be simulated value');
        assert(report.events.len() == 1, 'Should capture one event');
    }

    #[test]
    fn test_simulate_transaction_full_error() {
        let contract = DummyContractInteraction;
        let calldata = ArrayTrait::new();
        let report = simulate_transaction_full(
            contract,
            'TestContract',
            'fail', // triggers simulated error
            calldata.clone(),
            None,
            None
        );
        assert(!report.result.success, 'Simulation should fail');
        assert(report.result.error_message == 'Simulated error', 'Should return error message');
    }
}
