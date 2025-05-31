%lang starknet

@storage_var
func interaction_count(user: ContractAddress, action_id: felt) -> (count: felt):
end

@external
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
