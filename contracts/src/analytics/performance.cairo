%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.starknet.common.storage import Storage

@storage_var
func user_logs(user: felt, index: felt) -> (action_id: felt, timestamp: felt):
end

@storage_var
func user_log_count(user: felt) -> felt:
end

@external
func log_user_action{syscall_ptr: felt*}(action_id: felt):
    let (caller) = get_caller_address()
    let (timestamp) = get_block_timestamp()

    let (count) = user_log_count.read(caller)
    user_logs.write(caller, count, action_id, timestamp)
    user_log_count.write(caller, count + 1)

    return ()
end

@view
func get_user_logs{syscall_ptr: felt*}(
    user: felt, start: felt, length: felt
) -> (logs: felt*):
    alloc_locals
    let mut logs: felt* = alloc()

    let (total) = user_log_count.read(user)
    let end = if start + length > total { total } else { start + length }

    let mut i = start
    let mut j = 0
    while i < end:
        let (action_id, timestamp) = user_logs.read(user, i)
        assert [logs + j * 2] = action_id
        assert [logs + j * 2 + 1] = timestamp
        j = j + 1
        i = i + 1
    end

    return (logs)
end
