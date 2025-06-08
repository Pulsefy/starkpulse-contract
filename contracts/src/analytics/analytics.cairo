%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp, get_caller_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
use array::ArrayTrait;

// -------------------------------------------------------------------------------------
// EVENTS
// -------------------------------------------------------------------------------------
@event
func InteractionTracked(user: ContractAddress, action_id: felt, timestamp: felt):
end

@event
func PerformanceMetricsTracked(user: ContractAddress, action_id: felt, gas_used: felt, execution_time: felt):
end

// -------------------------------------------------------------------------------------
// STORAGE VARS
// -------------------------------------------------------------------------------------

@storage_var
func interaction_count(user: ContractAddress, action_id: felt) -> (count: felt):
end

@storage_var
func interaction_index(user: ContractAddress) -> (idx: felt):
end

@storage_var
func interaction_log(
    user: ContractAddress,
    idx: felt
) -> (
    action_id: felt,
    timestamp: felt
):
end

@storage_var
func performance_log(
    user: ContractAddress,
    action_id: felt
) -> (
    total_gas: felt,
    total_exec_time: felt,
    entry_count: felt
):
end

// -------------------------------------------------------------------------------------
// EXTERNAL FUNCTION: TRACK INTERACTION
// -------------------------------------------------------------------------------------
@external
func track_interaction{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    action_id: felt,
    gas_used: felt,
    execution_time: felt
):
    // 1. Bump interaction count
    let (old_count) = interaction_count.read(user, action_id);
    interaction_count.write(user, action_id, old_count + 1);

    // 2. Log full interaction (for history)
    let (idx) = interaction_index.read(user);
    let (ts) = get_block_timestamp();
    interaction_log.write(user, idx, (action_id, ts));
    interaction_index.write(user, idx + 1);

    // 3. Emit event for off-chain tracking
    emit InteractionTracked(user, action_id, ts);

    // 4. Log performance (aggregate tracking)
    let (prev_gas, prev_exec, prev_count) = performance_log.read(user, action_id);
    performance_log.write(
        user,
        action_id,
        (
            prev_gas + gas_used,
            prev_exec + execution_time,
            prev_count + 1
        )
    );

    emit PerformanceMetricsTracked(user, action_id, gas_used, execution_time);
    return ();
end

// -------------------------------------------------------------------------------------
// VIEWS
// -------------------------------------------------------------------------------------
@view
func get_user_action_count{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    action_id: felt
) -> (count: felt):
    let (cnt) = interaction_count.read(user, action_id);
    return (cnt,);
end

@view
func get_user_logs{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    start: felt,
    length: felt
) -> (logs: Array<(felt, felt)>):
    let mut result: Array<(felt, felt)> = ArrayTrait::new();
    let (total_idx) = interaction_index.read(user);

    let mut i = 0;
    while i < length:
        let real_idx = start + i;
        if real_idx < total_idx {
            let (aid, ts) = interaction_log.read(user, real_idx);
            result.append((aid, ts));
        } else {
            result.append((0, 0));
        }
        i += 1;
    end
    return (result,);
end

@view
func get_performance_summary{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    action_id: felt
) -> (avg_gas: felt, avg_exec_time: felt):
    let (total_gas, total_exec, count) = performance_log.read(user, action_id);
    if count == 0 {
        return (0, 0);
    } else {
        return (total_gas / count, total_exec / count);
    }
end

// -------------------------------------------------------------------------------------
// METADATA
// -------------------------------------------------------------------------------------
use contracts::src::utils::contract_metadata::{ContractMetadata, IContractMetadata};

const CONTRACT_VERSION: felt252 = '1.0.0';
const DOC_URL: felt252 = 'https://github.com/Pulsefy/starkpulse-contract?tab=readme-ov-file#analytics-store';
const INTERFACE_ANALYTICS: felt252 = 'IAnalytics';
const DEPENDENCY_NONE: felt252 = 'None';

#[abi(embed_v0)]
impl MetadataImpl of IContractMetadata<ContractState> {
    fn get_metadata(self: @ContractState) -> (metadata: ContractMetadata) {
        let mut interfaces = ArrayTrait::new();
        interfaces.append(INTERFACE_ANALYTICS);
        let mut dependencies = ArrayTrait::new();
        dependencies.append(DEPENDENCY_NONE);
        let metadata = ContractMetadata {
            version: CONTRACT_VERSION,
            documentation_url: DOC_URL,
            interfaces: interfaces,
            dependencies: dependencies,
        };
        (metadata,)
    }
    fn supports_interface(self: @ContractState, interface_id: felt252) -> (supported: felt252) {
        if interface_id == INTERFACE_ANALYTICS {
            (1,)
        } else {
            (0,)
        }
    }
}
