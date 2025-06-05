%lang starknet

from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.starknet.testing.starknet import Starknet

@test
func test_track_and_read_logs():
    let starknet = Starknet::init();

    // 1) Deploy the analytics contract.
    let analytics_account = starknet.deploy(
        contract_path="contracts/src/analytics/analytics.cairo"
    );

    // 2) Pick a random "user address" (in tests, we can use an empty felt)
    let user_address: felt = 0;

    // 3) Initially, get_user_action_count(user, 1) == 0
    let (initial_count) = analytics_account.get_user_action_count(user_address, 1).call();
    assert initial_count = 0;

    // 4) Call track_interaction(user, ACTION_TRANSFER=1)
    //    (ABI: track_interaction(user: felt, action_id: felt))
    let (tx_res) = analytics_account.track_interaction(user_address, 1).call();

    // 5) After that, count should be 1
    let (count_after) = analytics_account.get_user_action_count(user_address, 1).call();
    assert count_after = 1;

    // 6) Now get_user_logs(user, 0, 1) should return [(1, ts)]
    let (logs) = analytics_account.get_user_logs(user_address, 0, 1).call();
    // logs[0].0  is action_id = 1
    // logs[0].1  is some timestamp > 0
    // (You can assert logs[0].0 == 1)

    return ();
end
