// SPDX-License-Identifier: MIT
// Contract Metadata Standard for StarkPulse

%lang starknet

struct ContractMetadata {
    version: felt252,
    documentation_url: felt252,
    interfaces: Array<felt252>, // Interface IDs or names
    dependencies: Array<felt252> // Contract names or addresses
}
@contract_interface
namespace IContractMetadata {
    func get_metadata() -> (metadata: ContractMetadata) {
    }
    func supports_interface(interface_id: felt252) -> (supported: felt252) {
    }
}