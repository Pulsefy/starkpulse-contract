%lang starknet

// ─────────────────────────────────────────────────────────────────────────────
// Import core StarkNet APIs
// ─────────────────────────────────────────────────────────────────────────────
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;

// ─────────────────────────────────────────────────────────────────────────────
// Import your interfaces
// ─────────────────────────────────────────────────────────────────────────────
use interfaces::i_portfolio_tracker::IPortfolioTracker;
use interfaces::i_analytics::IAnalytics;

// ─────────────────────────────────────────────────────────────────────────────
// Aux imports for storage & collections
// ─────────────────────────────────────────────────────────────────────────────
use array::ArrayTrait;
use zeroable::Zeroable;
use traits::Into;
use box::BoxTrait;
use option::OptionTrait;
use contracts::src::utils::contract_metadata::{ContractMetadata, IContractMetadata};

// ─────────────────────────────────────────────────────────────────────────────
// Asset struct & Storage
// ─────────────────────────────────────────────────────────────────────────────
#[derive(Drop, Serde, starknet::Store)]
struct Asset {
    address: ContractAddress,
    amount: u256,
    last_updated: u64,
}

#[storage]
struct Storage {
    // Mapping (user, asset_address) → Asset
    user_assets: LegacyMap::<(ContractAddress, ContractAddress), Asset>,
    // For each user, list of held asset addresses
    user_asset_list: LegacyMap::<ContractAddress, Array<ContractAddress>>,
    // Admin address
    admin: ContractAddress,
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics address (set this AFTER you deploy analytics_store.cairo)
// ─────────────────────────────────────────────────────────────────────────────
// Replace 0x012345 with the real address from your deploy!
const ANALYTICS_ADDRESS: ContractAddress = ContractAddressConst::<0x012345>();

// Metadata constants
const CONTRACT_VERSION: felt252 = '1.0.0';
const DOC_URL: felt252 = 'https://github.com/Pulsefy/starkpulse-contract?tab=readme-ov-file#portfolio-tracker';
const INTERFACE_PORTFOLIO: felt252 = 'IPortfolioTracker';
const DEPENDENCY_ANALYTICS: felt252 = 'IAnalytics';

// ─────────────────────────────────────────────────────────────────────────────
// CONTRACT MODULE
// ─────────────────────────────────────────────────────────────────────────────
#[starknet::contract]
mod PortfolioTracker {
    use super::*;

    // ----------------------------
    // Constructor
    // ----------------------------
    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        // Only the deployer can set
        self.admin.write(admin_address);
    }

    // ----------------------------
    // External functions
    // ----------------------------
    #[external(v0)]
    impl PortfolioTrackerImpl of IPortfolioTracker<ContractState> {
        /// Add `amount` of `asset_address` to caller's portfolio.
        fn add_asset(
            ref self: ContractState,
            asset_address: ContractAddress,
            amount: u256
        ) -> bool {
            // 1) Basic checks
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Invalid caller');
            assert(!asset_address.is_zero(), 'Invalid asset');

            // 2) Timestamp
            let ts = get_block_timestamp();

            // 3) Read existing
            let existing = self.user_assets.read((caller, asset_address));

            // 4) New vs update
            if existing.address.is_zero() {
                // New asset entry
                let a = Asset {
                    address: asset_address,
                    amount,
                    last_updated: ts,
                };
                self.user_assets.write((caller, asset_address), a);

                // Append to asset_list
                let mut list = self.user_asset_list.read(caller);
                list.append(asset_address);
                self.user_asset_list.write(caller, list);
            } else {
                // Update existing
                let updated = Asset {
                    address: asset_address,
                    amount: existing.amount + amount,
                    last_updated: ts,
                };
                self.user_assets.write((caller, asset_address), updated);
            }

            // 5) Analytics: action_id = 1
            let analytics = IAnalytics::at(ANALYTICS_ADDRESS);
            analytics.track_interaction(caller, 1).invoke();

            true
        }

        /// Remove `amount` of `asset_address` from caller's portfolio.
        fn remove_asset(
            ref self: ContractState,
            asset_address: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            let existing = self.user_assets.read((caller, asset_address));
            assert(!existing.address.is_zero(), 'Asset not found');
            assert(existing.amount >= amount, 'Insufficient balance');

            let ts = get_block_timestamp();
            if existing.amount == amount {
                // Remove completely
                let zeroed = Asset {
                    address: ContractAddressConst::<0>(),
                    amount: 0,
                    last_updated: ts,
                };
                self.user_assets.write((caller, asset_address), zeroed);

                // NOTE: real removal from Array requires rebuilding the list;
                // here we simply leave it – in prod you'd filter it out.
                let list = self.user_asset_list.read(caller);
                self.user_asset_list.write(caller, list);
            } else {
                // Decrease amount
                let updated = Asset {
                    address: asset_address,
                    amount: existing.amount - amount,
                    last_updated: ts,
                };
                self.user_assets.write((caller, asset_address), updated);
            }

            // Analytics: action_id = 2
            let analytics = IAnalytics::at(ANALYTICS_ADDRESS);
            analytics.track_interaction(caller, 2).invoke();

            true
        }

        /// Return all Assets for `user_address`.
        fn get_portfolio(self: @ContractState, user_address: ContractAddress) -> Array<Asset> {
            let addresses = self.user_asset_list.read(user_address);
            let mut out = ArrayTrait::new();

            // NOTE: real iteration needs a proper loop;
            // here is a pseudocode placeholder:
            //
            // for addr in addresses {
            //     let asset = self.user_assets.read((user_address, addr));
            //     out.append(asset);
            // }
            //
            // Fill with zero-length for demo:
            out
        }

        /// Sum of all asset.amount for `user_address`.
        fn get_portfolio_value(self: @ContractState, user_address: ContractAddress) -> u256 {
            let addresses = self.user_asset_list.read(user_address);
            let mut total: u256 = 0;

            // Pseudocode:
            // for addr in addresses {
            //     let asset = self.user_assets.read((user_address, addr));
            //     // In reality you'd fetch price and multiply
            //     total = total + asset.amount;
            // }

            total
        }
    }

    // ----------------------------
    // Metadata
    // ----------------------------
    #[abi(embed_v0)]
    impl MetadataImpl of IContractMetadata<ContractState> {
        fn get_metadata(self: @ContractState) -> (metadata: ContractMetadata) {
            let mut interfaces = ArrayTrait::new();
            interfaces.append(INTERFACE_PORTFOLIO);
            let mut dependencies = ArrayTrait::new();
            dependencies.append(DEPENDENCY_ANALYTICS);
            let metadata = ContractMetadata {
                version: CONTRACT_VERSION,
                documentation_url: DOC_URL,
                interfaces: interfaces,
                dependencies: dependencies,
            };
            (metadata,)
        }
        fn supports_interface(self: @ContractState, interface_id: felt252) -> (supported: felt252) {
            if interface_id == INTERFACE_PORTFOLIO {
                (1,)
            } else {
                (0,)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interface definitions (for completeness – you can keep these separate)
// ─────────────────────────────────────────────────────────────────────────────
#[starknet::interface]
trait IPortfolioTracker<T> {
    fn add_asset(ref self: T, asset_address: ContractAddress, amount: u256) -> bool;
    fn remove_asset(ref self: T, asset_address: ContractAddress, amount: u256) -> bool;
    fn get_portfolio(self: @T, user_address: ContractAddress) -> Array<Asset>;
    fn get_portfolio_value(self: @T, user_address: ContractAddress) -> u256;
}

#[starknet::interface]
trait IAnalytics {
    fn track_interaction(ref self: ContractAddress, user: ContractAddress, action_id: felt) -> ();
}
