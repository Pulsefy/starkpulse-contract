%lang starknet

// ==============================
// File: contracts/src/tokens/my_token.cairo
// ==============================

from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.cairo_builtins import HashBuiltin

// ─────────────────────────────────────────────────────────────────────────────
// (1) Import your analytics interface
// ─────────────────────────────────────────────────────────────────────────────
from contracts.src.analytics.analytics import track_interaction
from contracts.src.utils.action_ids import ACTION_TRANSFER

@contract_interface
namespace IERC20:
    func transfer(
        recipient: ContractAddress,
        amount: Uint256
    ) -> (success: felt):
    end
end

@storage_var
func balances(account: ContractAddress) -> (res: Uint256):
end

@external
func transfer{syscall_ptr: felt*, range_check_ptr}(
    recipient: ContractAddress,
    amount: Uint256
) -> (success: felt):
    // ─────────────────────────────────────────────────────────────────────────
    // (2) Standard token‐transfer logic (pseudo-code)
    // ─────────────────────────────────────────────────────────────────────────
    let (caller) = get_caller_address();
    let (from_balance) = balances.read(caller);
    // … subtract/require/call logic to transfer `amount` …
    balances.write(caller, /* new balance */ from_balance);  
    let (to_balance) = balances.read(recipient);
    balances.write(recipient, /* new balance + amount */ to_balance);  

    // ─────────────────────────────────────────────────────────────────────────
    // (3) Now log this interaction ON‐CHAIN
    //     We pass (user = caller) and (action_id = ACTION_TRANSFER).
    // ─────────────────────────────────────────────────────────────────────────
    track_interaction(caller, ACTION_TRANSFER);

    return (1,);
end

// … rest of your ERC20 code …
