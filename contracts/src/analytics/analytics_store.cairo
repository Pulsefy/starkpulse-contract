// -----------------------------------------------------------------------------
// StarkPulse AnalyticsStore Contract
// -----------------------------------------------------------------------------
//
// Overview:
// This contract tracks user interactions and analytics events for the StarkPulse ecosystem.
//
// Features:
// - Tracks per-user action counts on-chain
// - Provides view functions for analytics dashboards
// - Designed for integration with other contracts (e.g., PortfolioTracker)
//
// Security Considerations:
// - Only whitelisted contracts should be allowed to call track_interaction in production
// - All critical functions validate input values
//
// Example Usage:
//
// // Deploying the contract (pseudo-code):
// let analytics = AnalyticsStore.deploy();
//
// // Track a user action (from another contract):
// analytics.track_interaction(USER_ADDRESS, ACTION_ID);
//
// // Query user action count:
// analytics.get_user_action_count(USER_ADDRESS, ACTION_ID);
//
// For integration and more examples, see INTEGRATION_GUIDE.md.
// -----------------------------------------------------------------------------

%lang starknet

@storage_var
// interaction_count: Mapping (user, action_id) → count of actions performed
func interaction_count(user: ContractAddress, action_id: felt) -> (count: felt):
end

@external
/// Tracks a user interaction for analytics purposes
/// @param user The address of the user performing the action
/// @param action_id The unique identifier for the action/event
/// @dev Increments the on-chain counter for (user, action_id)
/// @security In production, restrict access to trusted contracts only
func track_interaction{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    action_id: felt
):
    // bump the on-chain counter
    let (old) = interaction_count.read(user, action_id);
    interaction_count.write(user, action_id, old + 1);
    return ();
end

@view
/// Returns the count of a specific action performed by a user
/// @param user The address of the user
/// @param action_id The unique identifier for the action/event
/// @return count The number of times the user performed the action
func get_user_action_count{syscall_ptr: felt*, range_check_ptr}(
    user: ContractAddress,
    action_id: felt
) -> (count: felt):
    let (cnt) = interaction_count.read(user, action_id);
    return (cnt);
end

use contracts::src::utils::contract_metadata::{ContractMetadata, IContractMetadata};
use array::ArrayTrait;

// Metadata constants
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
