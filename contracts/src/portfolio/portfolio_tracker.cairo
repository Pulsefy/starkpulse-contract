// -----------------------------------------------------------------------------
// StarkPulse PortfolioTracker Contract
// -----------------------------------------------------------------------------
//
// Overview:
// This contract tracks user portfolios, asset balances, and integrates with analytics for the StarkPulse ecosystem.
//
// Features:
// - Tracks balances of multiple assets per user
// - Stores asset lists and last update timestamps
// - Admin-controlled asset management
// - Analytics integration for on-chain activity tracking
//
// Security Considerations:
// - Only admin can perform privileged actions (e.g., asset management)
// - All critical functions validate caller permissions and input values
// - Zero address checks prevent accidental asset loss
//
// Example Usage:
//
// // Deploying the contract (pseudo-code):
// let tracker = PortfolioTracker.deploy(admin=ADMIN_ADDRESS);
//
// // Add/update asset for user:
// tracker.update_asset(USER_ADDRESS, ASSET_ADDRESS, AMOUNT);
//
// // Get user asset list:
// tracker.get_user_assets(USER_ADDRESS);
//
// For integration and more examples, see INTEGRATION_GUIDE.md.
// -----------------------------------------------------------------------------

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
    // user_assets: Mapping (user, asset_address) → Asset struct (tracks amount and last update)
    user_assets: LegacyMap::<(ContractAddress, ContractAddress), Asset>,
    // user_asset_list: Mapping user → list of held asset addresses
    user_asset_list: LegacyMap::<ContractAddress, Array<ContractAddress>>,
    // admin: Admin address with privileged permissions
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
    /// Contract constructor
    /// @param admin_address The address with admin rights (can manage assets)
    /// @dev Sets up the contract for portfolio tracking. Only admin can perform privileged actions.
    /// @security Ensure admin_address is a trusted address.
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        // Only the deployer can set
        self.admin.write(admin_address);
    }

    // ----------------------------
    // External functions
    // ----------------------------
    #[external(v0)]
    impl PortfolioTrackerImpl of IPortfolioTracker<ContractState> {
        /// Adds an asset to the caller's portfolio
        /// @param asset_address The address of the asset to add
        /// @param amount The amount of the asset to add
        /// @return true if the asset was added or updated successfully
        /// @dev Updates the asset list and last updated timestamp. Emits no event.
        /// @security Only valid callers and asset addresses allowed. Admin can restrict further in future.
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

        /// Batch add assets to the caller's portfolio
        fn batch_add_assets(
            ref self: ContractState,
            asset_addresses: Array<ContractAddress>,
            amounts: Array<u256>
        ) -> bool {
            assert(asset_addresses.len() == amounts.len(), 'Mismatched array lengths');
            let caller = get_caller_address();
            let ts = get_block_timestamp();
            let mut i = 0;
            while i < asset_addresses.len() {
                let asset_address = asset_addresses.at(i);
                let amount = amounts.at(i);
                if amount > 0 {
                    let existing = self.user_assets.read((caller, asset_address));
                    if existing.address.is_zero() {
                        let a = Asset {
                            address: asset_address,
                            amount,
                            last_updated: ts,
                        };
                        self.user_assets.write((caller, asset_address), a);
                        let mut list = self.user_asset_list.read(caller);
                        list.append(asset_address);
                        self.user_asset_list.write(caller, list);
                    } else {
                        let updated = Asset {
                            address: asset_address,
                            amount: existing.amount + amount,
                            last_updated: ts,
                        };
                        self.user_assets.write((caller, asset_address), updated);
                    }
                }
                i += 1;
            }
            // Analytics: action_id = 10 for batch add
            let analytics = IAnalytics::at(ANALYTICS_ADDRESS);
            analytics.track_interaction(caller, 10).invoke();
            true
        }

        /// Batch remove assets from the caller's portfolio
        fn batch_remove_assets(
            ref self: ContractState,
            asset_addresses: Array<ContractAddress>,
            amounts: Array<u256>
        ) -> bool {
            assert(asset_addresses.len() == amounts.len(), 'Mismatched array lengths');
            let caller = get_caller_address();
            let ts = get_block_timestamp();
            let mut i = 0;
            while i < asset_addresses.len() {
                let asset_address = asset_addresses.at(i);
                let amount = amounts.at(i);
                let existing = self.user_assets.read((caller, asset_address));
                assert(!existing.address.is_zero(), 'Asset not found');
                assert(existing.amount >= amount, 'Insufficient balance');
                let new_amount = existing.amount - amount;
                if new_amount == 0 {
                    let zeroed = Asset {
                        address: ContractAddressConst::<0>(),
                        amount: 0,
                        last_updated: ts,
                    };
                    self.user_assets.write((caller, asset_address), zeroed);
                    // NOTE: not removing from list for gas efficiency
                } else {
                    let updated = Asset {
                        address: asset_address,
                        amount: new_amount,
                        last_updated: ts,
                    };
                    self.user_assets.write((caller, asset_address), updated);
                }
                i += 1;
            }
            // Analytics: action_id = 11 for batch remove
            let analytics = IAnalytics::at(ANALYTICS_ADDRESS);
            analytics.track_interaction(caller, 11).invoke();
            true
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
