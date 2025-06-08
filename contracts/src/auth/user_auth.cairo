#[starknet::contract]
mod UserAuth {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::Map;
    use zeroable::Zeroable;
    use contracts::src::utils::contract_metadata::{ContractMetadata, IContractMetadata};
    use array::ArrayTrait;
    use contracts::src::utils::access_control::{AccessControl, IAccessControl};
    use contracts::src::interfaces::i_user_auth::{IUserAuth, UserProfile, Session, UserAuthTypes};
    use starkpulse::utils::error_handling::{ErrorHandling, ErrorHandlingImpl, error_codes};

    // Metadata constants
    const CONTRACT_VERSION: felt252 = '1.0.0';
    const DOC_URL: felt252 = 'https://github.com/Pulsefy/starkpulse-contract?tab=readme-ov-file#user-auth';
    const INTERFACE_USER_AUTH: felt252 = 'IUserAuth';
    const DEPENDENCY_ACCESS_CONTROL: felt252 = 'IAccessControl';

    // Constants for session status
    const SESSION_ACTIVE: felt252 = 'ACTIVE';
    const SESSION_EXPIRED: felt252 = 'EXPIRED';
    const SESSION_LOGGED_OUT: felt252 = 'LOGGED_OUT';
    
    // Constants for session duration (in seconds)
    const DEFAULT_SESSION_DURATION: u64 = 86400; // 24 hours
    const MAX_FAILED_LOGIN_ATTEMPTS: u32 = 5;
    const LOGIN_COOLDOWN: u64 = 300; // 5 minutes
    
    // Constants for roles
    const ROLE_ADMIN: felt252 = 'ADMIN';
    const ROLE_USER: felt252 = 'USER';
    const ROLE_MODERATOR: felt252 = 'MODERATOR';

    #[storage]
    struct Storage {
        // User profiles
        users: Map<ContractAddress, UserProfile>,
        usernames: Map<felt252, ContractAddress>,
        registered_users: u64,
        
        // Session management
        user_sessions: Map<ContractAddress, Session>,
        session_count: u64,
        
        // Nonce management for signature verification
        user_nonces: Map<ContractAddress, u64>,
        
        // Access control
        access_control: IAccessControl,
        
        // Admin address
        admin: ContractAddress,
        
        // Emergency recovery addresses
        recovery_addresses: Map<ContractAddress, ContractAddress>,
        
    // MFA management
    mfa_backup_codes: Map<ContractAddress, Array<felt252>>,

    // Error handling
    _is_active: Map<ContractAddress, bool>,
    _is_blocked: Map<ContractAddress, bool>,
    _registration_time: Map<ContractAddress, u64>,
}


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserRegistered: UserRegistered,
        UserLoggedIn: UserLoggedIn,
        UserLoggedOut: UserLoggedOut,
        SessionExpired: SessionExpired,
        SessionRenewed: SessionRenewed,
        ProfileUpdated: ProfileUpdated,
        UsernameChanged: UsernameChanged,
        ProfileDeleted: ProfileDeleted,
        AdminRightsTransferred: AdminRightsTransferred,
        EmergencyRecoverySet: EmergencyRecoverySet,
        EmergencyRecoveryUsed: EmergencyRecoveryUsed,
        MFAEnabled: MFAEnabled,
        MFADisabled: MFADisabled,
        LoginAttemptFailed: LoginAttemptFailed,
    }

    #[derive(Drop, starknet::Event)]
    struct UserRegistered {
        user: ContractAddress,
        username: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UserLoggedIn {
        user: ContractAddress,
        session_id: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UserLoggedOut {
        user: ContractAddress,
        session_id: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct SessionExpired {
        user: ContractAddress,
        session_id: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct SessionRenewed {
        user: ContractAddress,
        session_id: felt252,
        new_expiry: u64,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileUpdated {
        user: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct UsernameChanged {
        user: ContractAddress,
        old_username: felt252,
        new_username: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileDeleted {
        user: ContractAddress,
        username: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct AdminRightsTransferred {
        old_admin: ContractAddress,
        new_admin: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyRecoverySet {
        user: ContractAddress,
        recovery_address: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct EmergencyRecoveryUsed {
        user: ContractAddress,
        recovery_address: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct MFAEnabled {
        user: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct MFADisabled {
        user: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct LoginAttemptFailed {
        user: ContractAddress,
        reason: felt252,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        // Initialize contract
        self.admin.write(admin_address);
        self.registered_users.write(0);
        self.session_count.write(0);
    }

    #[external(v0)]
    impl UserAuthImpl of IUserAuth<ContractState> {
        // User Registration
        fn register_user(
            ref self: ContractState,
            username: felt252,
            display_name: felt252,
            email_hash: felt252,
            mfa_secret: felt252
        ) -> bool {
            let caller = get_caller_address();
            
            // Validate inputs
            assert(username != 0, "Username cannot be empty");
            assert(display_name != 0, "Display name cannot be empty");
            
            // Check if user already exists
            let existing_user = self.users.read(caller);
            assert(existing_user.address.is_zero(), "User already registered");
            
            // Check if username is taken
            let username_owner = self.usernames.read(username);
            assert(username_owner.is_zero(), "Username already taken");
            
            // Create user profile
            let user_profile = UserProfile {
                address: caller,
                username: username,
                display_name: display_name,
                email_hash: email_hash,
                created_at: get_block_timestamp(),
                last_login: 0,
                mfa_enabled: false,
                mfa_secret: mfa_secret,
                failed_login_attempts: 0,
                last_failed_login: 0,
                role: ROLE_USER,
            };
            
            // Store user data
            self.users.write(caller, user_profile);
            self.usernames.write(username, caller);
            
            // Initialize nonce
            self.user_nonces.write(caller, 0);
            
            // Increment registered users count
            let current_count = self.registered_users.read();
            self.registered_users.write(current_count + 1);
            
            // Emit event
            self.emit(UserRegistered {
                user: caller,
                username: username,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        // Login functionality
        fn login(
            ref self: ContractState,
            signature: Array<felt252>,
            message_hash: felt252,
            nonce: u64,
            mfa_code: felt252
        ) -> felt252 {
            let caller = get_caller_address();
            
            // Verify user exists
            let mut user = self.users.read(caller);
            assert(!user.address.is_zero(), "User not registered");
            
            // Check for login cooldown
            let current_time = get_block_timestamp();
            if user.failed_login_attempts >= MAX_FAILED_LOGIN_ATTEMPTS {
                let cooldown_end = user.last_failed_login + LOGIN_COOLDOWN;
                assert(current_time >= cooldown_end, "Account temporarily locked");
            }
            
            // Verify nonce
            let current_nonce = self.user_nonces.read(caller);
            assert(nonce == current_nonce, "Invalid nonce");
            
            // Verify signature (simplified - in production would use proper signature verification)
            assert(signature.len() > 0, "Invalid signature");
            
            // Verify MFA if enabled
            if user.mfa_enabled {
                assert(mfa_code != 0, "MFA code required");
                // In production, implement proper TOTP verification
                assert(mfa_code == user.mfa_secret, "Invalid MFA code");
            }
            
            // Increment nonce to prevent replay attacks
            self.user_nonces.write(caller, current_nonce + 1);
            
            // Generate session ID (simplified - in production would use more secure method)
            let timestamp = get_block_timestamp();
            let session_id = message_hash;
            
            // Create new session
            let session = Session {
                id: session_id,
                user: caller,
                status: SESSION_ACTIVE,
                created_at: timestamp,
                expires_at: timestamp + DEFAULT_SESSION_DURATION,
                last_activity: timestamp,
                mfa_verified: user.mfa_enabled,
                device_info: message_hash, // In production, would include device fingerprint
            };
            
            // Store session
            self.user_sessions.write(caller, session);
            
            // Update user profile
            user.last_login = timestamp;
            user.failed_login_attempts = 0;
            self.users.write(caller, user);
            
            // Increment session count
            let current_count = self.session_count.read();
            self.session_count.write(current_count + 1);
            
            // Emit event
            self.emit(UserLoggedIn {
                user: caller,
                session_id: session_id,
                timestamp: timestamp,
            });
            
            session_id
        }
        
        // MFA Management
        fn enable_mfa(ref self: ContractState, mfa_secret: felt252) -> bool {
            let caller = get_caller_address();
            let mut user = self.users.read(caller);
            
            assert(!user.mfa_enabled, "MFA already enabled");
            assert(mfa_secret != 0, "Invalid MFA secret");
            
            user.mfa_enabled = true;
            user.mfa_secret = mfa_secret;
            self.users.write(caller, user);
            
            self.emit(MFAEnabled {
                user: caller,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        fn disable_mfa(ref self: ContractState, mfa_code: felt252) -> bool {
            let caller = get_caller_address();
            let mut user = self.users.read(caller);
            
            assert(user.mfa_enabled, "MFA not enabled");
            assert(mfa_code == user.mfa_secret, "Invalid MFA code");
            
            user.mfa_enabled = false;
            user.mfa_secret = 0;
            self.users.write(caller, user);
            
            self.emit(MFADisabled {
                user: caller,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        fn verify_mfa(self: @ContractState, user_address: ContractAddress, mfa_code: felt252) -> bool {
            let user = self.users.read(user_address);
            if !user.mfa_enabled {
                return true;
            }
            
            mfa_code == user.mfa_secret
        }
        
        // Session Management
        fn renew_session(ref self: ContractState, session_id: felt252) -> bool {
            let caller = get_caller_address();
            let mut session = self.user_sessions.read(caller);
            
            assert(session.id == session_id, "Invalid session ID");
            assert(session.status == SESSION_ACTIVE, "Session not active");
            
            let current_time = get_block_timestamp();
            assert(current_time < session.expires_at, "Session already expired");
            
            // Renew session
            session.expires_at = current_time + DEFAULT_SESSION_DURATION;
            session.last_activity = current_time;
            self.user_sessions.write(caller, session);
            
            self.emit(SessionRenewed {
                user: caller,
                session_id: session_id,
                new_expiry: session.expires_at,
                timestamp: current_time,
            });
            
            true
        }
        
        // Account Recovery
        fn recover_account(
            ref self: ContractState,
            user_address: ContractAddress,
            recovery_proof: Array<felt252>
        ) -> bool {
            let caller = get_caller_address();
            let recovery_address = self.recovery_addresses.read(user_address);
            
            assert(recovery_address == caller, "Unauthorized recovery attempt");
            assert(recovery_proof.len() > 0, "Invalid recovery proof");
            
            // In production, implement proper recovery proof verification
            
            // Reset user's failed login attempts
            let mut user = self.users.read(user_address);
            user.failed_login_attempts = 0;
            user.last_failed_login = 0;
            self.users.write(user_address, user);
            
            // Invalidate all existing sessions
            let session = Session {
                id: 0,
                user: user_address,
                status: SESSION_LOGGED_OUT,
                created_at: get_block_timestamp(),
                expires_at: 0,
                last_activity: 0,
                mfa_verified: false,
                device_info: 0,
            };
            self.user_sessions.write(user_address, session);
            
            self.emit(EmergencyRecoveryUsed {
                user: user_address,
                recovery_address: caller,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        // View Functions
        fn is_mfa_enabled(self: @ContractState, user_address: ContractAddress) -> bool {
            let user = self.users.read(user_address);
            user.mfa_enabled
        }
        
        // Logout functionality
        fn logout(ref self: ContractState) -> bool {
            let caller = get_caller_address();
            
            // Get current session
            let mut session = self.user_sessions.read(caller);
            assert(session.id != 0, "No active session");
            assert(session.status == SESSION_ACTIVE, "Session not active");
            
            // Update session status
            session.status = SESSION_LOGGED_OUT;
            self.user_sessions.write(caller, session);
            
            // Emit event
            self.emit(UserLoggedOut {
                user: caller,
                session_id: session.id,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        // Validate session
        fn validate_session(self: @ContractState, user_address: ContractAddress) -> bool {
            let session = self.user_sessions.read(user_address);
            
            // Check if session exists and is active
            if session.id == 0 || session.status != SESSION_ACTIVE {
                return false;
            }
            
            // Check if session has expired
            let current_time = get_block_timestamp();
            if current_time > session.expires_at {
                return false;
            }
            
            true
        }
        
        // Update user profile
        fn update_profile(
            ref self: ContractState,
            display_name: felt252,
            email_hash: felt252
        ) -> bool {
            let caller = get_caller_address();
            
            // Verify user exists
            let mut user = self.users.read(caller);
            assert(!user.address.is_zero(), "User not registered");
            
            // Validate session
            assert(self.validate_session(@self, caller), "No active session");
            
            // Update profile
            if display_name != 0 {
                user.display_name = display_name;
            }
            
            if email_hash != 0 {
                user.email_hash = email_hash;
            }
            
            // Save updated profile
            self.users.write(caller, user);
            
            // Emit event
            self.emit(ProfileUpdated {
                user: caller,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        // Change username
        fn change_username(ref self: ContractState, new_username: felt252) -> bool {
            let caller = get_caller_address();
            
            // Validate input
            assert(new_username != 0, "Username cannot be empty");
            
            // Verify user exists
            let mut user = self.users.read(caller);
            assert(!user.address.is_zero(), "User not registered");
            
            // Validate session
            assert(self.validate_session(@self, caller), "No active session");
            
            // Check if new username is taken
            let username_owner = self.usernames.read(new_username);
            assert(username_owner.is_zero(), "Username already taken");
            
            // Store old username for event
            let old_username = user.username;
            
            // Update username mappings
            self.usernames.write(old_username, ContractAddress::zero());
            self.usernames.write(new_username, caller);
            
            // Update user profile
            user.username = new_username;
            self.users.write(caller, user);
            
            // Emit event
            self.emit(UsernameChanged {
                user: caller,
                old_username: old_username,
                new_username: new_username,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        // Delete profile
        fn delete_profile(ref self: ContractState) -> bool {
            let caller = get_caller_address();
            
            // Verify user exists
            let user = self.users.read(caller);
            assert(!user.address.is_zero(), "User not registered");
            
            // Store username for event
            let username = user.username;
            
            // Remove user data
            self.users.write(caller, UserProfile::zero());
            self.usernames.write(username, ContractAddress::zero());
            
            // Clear session data
            self.user_sessions.write(caller, Session::zero());
            
            // Decrement registered users count
            let current_count = self.registered_users.read();
            self.registered_users.write(current_count - 1);
            
            // Emit event
            self.emit(ProfileDeleted {
                user: caller,
                username: username,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        // Admin function to transfer admin rights
        fn transfer_admin(ref self: ContractState, new_admin: ContractAddress) -> bool {
            let caller = get_caller_address();
            
            // Verify caller is admin
            assert(caller == self.admin.read(), "Not authorized");
            
            // Transfer admin rights
            self.admin.write(new_admin);
            
            // Emit event
            self.emit(AdminRightsTransferred {
                old_admin: caller,
                new_admin: new_admin,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        // Set emergency recovery address
        fn set_recovery_address(ref self: ContractState, recovery_address: ContractAddress) -> bool {
            let caller = get_caller_address();
            
            // Verify user exists
            let user = self.users.read(caller);
            assert(!user.address.is_zero(), "User not registered");
            
            // Validate session
            assert(self.validate_session(@self, caller), "No active session");
            
            // Set recovery address
            self.recovery_addresses.write(caller, recovery_address);
            
            // Emit event
            self.emit(EmergencyRecoverySet {
                user: caller,
                recovery_address: recovery_address,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        // Get user profile
        fn get_user_profile(self: @ContractState, user_address: ContractAddress) -> UserProfile {
            self.users.read(user_address)
        }
        
        // Get user by username
        fn get_user_by_username(self: @ContractState, username: felt252) -> ContractAddress {
            self.usernames.read(username)
        }
        
        // Get session info
        fn get_session(self: @ContractState, user_address: ContractAddress) -> Session {
            self.user_sessions.read(user_address)
        }
        
        // Get current nonce for a user
        fn get_nonce(self: @ContractState, user_address: ContractAddress) -> u64 {
            self.user_nonces.read(user_address)
        }
        
        // Check if user has admin role
        fn is_admin(self: @ContractState, user_address: ContractAddress) -> bool {
            user_address == self.admin.read()
        }
        
        // Authenticate user
        fn authenticate_user(ref self: ContractState, user: ContractAddress) -> bool {
            if user.is_zero() {
                self.emit_error(error_codes::INVALID_ADDRESS, 'Invalid user address', 0);
                return false;
            }

            if !self._is_active.read(user) {
                self.emit_error(error_codes::STATE_INVALID, 'User account is not active', 0);
                return false;
            }

            if self._is_blocked.read(user) {
                self.emit_error(error_codes::UNAUTHORIZED_ACCESS, 'User account is blocked', 0);
                return false;
            }

            true
        }
    }
    
    // Internal functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        // Automatically expire sessions
        fn check_and_expire_session(ref self: ContractState, user_address: ContractAddress) {
            let mut session = self.user_sessions.read(user_address);
            
            // Check if session exists and is active
            if session.id != 0 && session.status == SESSION_ACTIVE {
                // Check if session has expired
                let current_time = get_block_timestamp();
                if current_time > session.expires_at {
                    // Update session status
                    session.status = SESSION_EXPIRED;
                    self.user_sessions.write(user_address, session);
                    
                    // Emit event
                    self.emit(SessionExpired {
                        user: user_address,
                        session_id: session.id,
                        timestamp: current_time,
                    });
                }
            }
        }
    }
    
    #[abi(embed_v0)]
    impl MetadataImpl of IContractMetadata<ContractState> {
        fn get_metadata(self: @ContractState) -> (metadata: ContractMetadata) {
            let mut interfaces = ArrayTrait::new();
            interfaces.append(INTERFACE_USER_AUTH);
            let mut dependencies = ArrayTrait::new();
            dependencies.append(DEPENDENCY_ACCESS_CONTROL);
            let metadata = ContractMetadata {
                version: CONTRACT_VERSION,
                documentation_url: DOC_URL,
                interfaces: interfaces,
                dependencies: dependencies,
            };
            (metadata,)
        }
        fn supports_interface(self: @ContractState, interface_id: felt252) -> (supported: felt252) {
            if interface_id == INTERFACE_USER_AUTH {
                (1,)
            } else {
                (0,)
            }
        }
    }
}
