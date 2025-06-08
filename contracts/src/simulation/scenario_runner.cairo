// Orchestrates scenario-based contract interaction tests
// ...implementation to be added...

use contracts::src::simulation::transaction_simulator::{simulate_transaction_with_hooks, SimulationResult, SimulationHook};
use contracts::src::interfaces::i_contract_interaction::IContractInteraction;
use starknet::{ArrayTrait};

#[derive(Drop, Serde, starknet::Store)]
struct ScenarioStep {
    contract_name: felt252,
    function_name: felt252,
    calldata: Array<felt252>,
}

#[derive(Drop, Serde, starknet::Store)]
struct ScenarioResult {
    steps: Array<SimulationResult>,
    success: bool,
}

fn run_scenario(
    contract: IContractInteraction,
    steps: Array<ScenarioStep>,
    pre_hook: Option<SimulationHook>,
    post_hook: Option<SimulationHook>
) -> ScenarioResult {
    let mut results = ArrayTrait::new();
    let mut all_success = true;
    let len = steps.len();
    let mut i = 0;
    while i < len {
        let step = steps.at(i);
        let result = simulate_transaction_with_hooks(
            contract,
            step.contract_name,
            step.function_name,
            step.calldata.clone(),
            pre_hook.clone(),
            post_hook.clone()
        );
        if !result.success {
            all_success = false;
        }
        results.append(result);
        i += 1;
    }
    ScenarioResult {
        steps: results,
        success: all_success,
    }
}
