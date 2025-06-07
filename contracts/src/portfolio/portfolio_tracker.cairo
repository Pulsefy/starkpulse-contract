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
use starkpulse::utils::error_handling::{ErrorHandling, ErrorHandlingImpl, error_codes};

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
            if self._paused.read() {
                self.emit_error(error_codes::CONTRACT_PAUSED, 'Contract is paused', 0);
                return false;
            }

            if asset_address.is_zero() {
                self.emit_error(error_codes::INVALID_ADDRESS, 'Invalid asset address', 0);
                return false;
            }

            // 1) Basic checks
            let caller = get_caller_address();
            assert(!caller.is_zero(), 'Invalid caller');

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

        /// Update asset for a user (admin only)
        /// @param user The user address
        /// @param asset The asset contract address
        /// @param amount The amount of the asset
        /// @return true if the operation was successful
        /// @dev This function is admin-only and bypasses normal checks.
        /// Emits an AssetUpdated event on success.
        /// @security Only the admin can call this function.
        fn update_asset(
            ref self: ContractState,
            user: ContractAddress,
            asset: ContractAddress,
            amount: u256
        ) -> bool {
            if self._paused.read() {
                self.emit_error(error_codes::CONTRACT_PAUSED, 'Contract is paused', 0);
                return false;
            }

            if user.is_zero() || asset.is_zero() {
                self.emit_error(error_codes::INVALID_ADDRESS, 'Invalid user or asset address', 0);
                return false;
            }

            let caller = get_caller_address();
            if caller != self._admin.read() {
                self.emit_error(error_codes::UNAUTHORIZED_ACCESS, 'Caller is not admin', 0);
                return false;
            }

            // Update asset balance
            self._user_assets.write((user, asset), amount);
            self._last_updates.write(user, get_block_timestamp());

            // Update asset list if needed
            let mut asset_list = self._asset_lists.read(user);
            if !asset_list.contains(asset) {
                asset_list.append(asset);
                self._asset_lists.write(user, asset_list);
            }

            // Emit event
            self.emit(AssetUpdated { user, asset, amount });
            true
        }

        /// Get a user's assets (public)
        /// @param user The user address
        /// @return Array of asset addresses
        /// @dev This function is public and can be called by anyone.
        /// It returns the list of assets for a given user.
        fn get_user_assets(self: @ContractState, user: ContractAddress) -> Array<ContractAddress> {
            if user.is_zero() {
                self.emit_error(error_codes::INVALID_ADDRESS, 'Invalid user address', 0);
                return ArrayTrait::new();
            }
            
            self._asset_lists.read(user)
        }

        /// Get the balance of an asset for a user (public)
        /// @param user The user address
        /// @param asset The asset contract address
        /// @return The balance of the asset
        /// @dev This function is public and can be called by anyone.
        /// It returns the balance of a specific asset for a given user.
        fn get_asset_balance(
            self: @ContractState,
            user: ContractAddress,
            asset: ContractAddress
        ) -> u256 {
            if user.is_zero() || asset.is_zero() {
                self.emit_error(error_codes::INVALID_ADDRESS, 'Invalid user or asset address', 0);
                return 0;
            }

            self._user_assets.read((user, asset))
        }

        /// Pause the contract (admin only)
        /// @dev This function pauses all asset updates. Useful for emergency stops.
        /// Can be called by the admin only.
        fn pause(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Only admin can pause');

            self.paused.write(true);
        }

        /// Unpause the contract (admin only)
        /// @dev This function resumes the contract after a pause.
        /// Can be called by the admin only.
        fn unpause(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), 'Only admin can unpause');

            self.paused.write(false);
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
