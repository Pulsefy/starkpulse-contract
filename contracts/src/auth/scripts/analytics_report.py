
from starknet_py.net.full_node_client import FullNodeClient
from starknet_py.contract import Contract

client = FullNodeClient("https://<your-starknet-node>")

async def fetch_usage_patterns(contract_address: str):
    contract = await Contract.from_address(contract_address, client)
    
    # Get logs (e.g., 0 to 50)
    logs = await contract.functions["get_user_logs"].call(user=0x123, start=0, length=50)
    
    # Analyze patterns
    action_counts = {}
    for (action_id, timestamp) in logs.logs:
        action_counts[action_id] = action_counts.get(action_id, 0) + 1

    # Summarize behavior
    sorted_actions = sorted(action_counts.items(), key=lambda x: x[1], reverse=True)
    print("Top actions:")
    for action, count in sorted_actions:
        print(f"Action {action}: {count} times")

async def fetch_performance(contract_address: str, user: int, action: int):
    contract = await Contract.from_address(contract_address, client)
    result = await contract.functions["get_performance_summary"].call(user=user, action_id=action)
    print(f"Avg Gas: {result.avg_gas}, Avg Execution Time: {result.avg_exec_time}")
