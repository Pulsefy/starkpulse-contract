%lang starknet

// =====================================================================================
// File: contracts/src/analytics/analytics.cairo
// =====================================================================================

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

// -------------------------------------------------------------------------------------
// STORAGE VARS
// -------------------------------------------------------------------------------------

/// How many times `user` has done `action_id`.
/// (Exactly what you had before.)
@storage_var
func interaction_count(user: ContractAddress, action_id: felt) -> (count: felt):
end

/// A running index for “how many logs” this user has.
/// When a new log is appended, we read this, append, then increment by 1.
@storage_var
func interaction_index(user: ContractAddress) -> (idx: felt):
end

/// Each user’s chronological logs.  Key is (user, idx). 
/// Value tuple is (action_id, timestamp).
@storage_var
func interaction_log(
    user: ContractAddress,
    idx: felt
) -> (
    action_id: felt,
    timestamp: felt
):
end

// -------------------------------------------------------------------------------------
// EXTERNAL: track_interaction
// -------------------------------------------------------------------------------------

/// Call from any contract you want to “log.”  
///   user: address calling or being tracked  
///   action_id: a small felt (see action_ids.cairo)  
@external
func track_interaction{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    action_id: felt
):
    // ────────────────────────────────────────────────────────────────────────────────
    // 1) Bump simple count(user, action_id)
    // ────────────────────────────────────────────────────────────────────────────────
    let (old_count) = interaction_count.read(user, action_id);
    interaction_count.write(user, action_id, old_count + 1);

    // ────────────────────────────────────────────────────────────────────────────────
    // 2) Append a new “full log entry” into interaction_log
    //    – First read the user’s current index (how many logs they already have)
    //    – Then store (action_id, timestamp) at that index
    //    – Then increment the index by 1.
    // ────────────────────────────────────────────────────────────────────────────────
    let (current_idx) = interaction_index.read(user);
    let (ts) = get_block_timestamp();  // current block timestamp

    interaction_log.write(user, current_idx, (action_id, ts));
    interaction_index.write(user, current_idx + 1);

    return ();
end

// -------------------------------------------------------------------------------------
// VIEW: get_user_action_count
//   (Identical to what you already had—just keep it.)
// -------------------------------------------------------------------------------------
@view
func get_user_action_count{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    action_id: felt
) -> (count: felt):
    let (cnt) = interaction_count.read(user, action_id);
    return (cnt);
end

// -------------------------------------------------------------------------------------
// VIEW: get_user_logs
//   Returns a slice of (action_id, timestamp) for a given user.
//   - “start” is the starting index (0-based).  
//   - “length” is how many consecutive entries to return.
//   For instance, start=0, length=5 returns the first 5 logs. 
//   If length goes past the end, missing entries default to (0,0).
// -------------------------------------------------------------------------------------
@view
func get_user_logs{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    start: felt,
    length: felt
) -> (logs: Array<(felt, felt)>):
    // Prepare a dynamic array (ArrayTrait) to hold our results.
    let mut result: Array<(felt, felt)> = ArrayTrait::new();

    // Read the user’s “total logs so far” so we can bound-check.
    let (total_idx) = interaction_index.read(user);

    // For i in [0 .. length-1]:
    //    real_idx = start + i
    //    if real_idx < total_idx: read from interaction_log
    //    else: append (0,0) as “empty slot”
    let mut i = 0;
    while i < length:
        let real_idx = start + i;
        if real_idx < total_idx {
            let (aid, ts) = interaction_log.read(user, real_idx);
            result.append((aid, ts));
        } else {
            // If user hasn’t logged that far, return a dummy (0,0).
            result.append((0, 0));
        }
        i += 1;
    }
    return (result,);
end

// -------------------------------------------------------------------------------------
// METADATA (unchanged from your original file; just keep it exactly as you had)
// -------------------------------------------------------------------------------------
use contracts::src::utils::contract_metadata::{ContractMetadata, IContractMetadata};
use array::ArrayTrait;

// Metadata constant
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
