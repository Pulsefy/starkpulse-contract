#[starknet::interface]
trait IUserAuth<TContractState> {
    // User Registration
    fn register_user(
        ref self: TContractState,
        username: felt252,
        display_name: felt252,
        email_hash: felt252,
        mfa_secret: felt252
    ) -> bool;
    
    // Login/Logout
    fn login(
        ref self: TContractState,
        signature: Array<felt252>,
        message_hash: felt252,
        nonce: u64,
        mfa_code: felt252
    ) -> felt252;
    
    fn logout(ref self: TContractState) -> bool;
    
    // Session Management
    fn validate_session(self: @TContractState, user_address: starknet::ContractAddress) -> bool;
    fn renew_session(ref self: TContractState, session_id: felt252) -> bool;
    
    // MFA Management
    fn enable_mfa(ref self: TContractState, mfa_secret: felt252) -> bool;
    fn disable_mfa(ref self: TContractState, mfa_code: felt252) -> bool;
    fn verify_mfa(self: @TContractState, user_address: starknet::ContractAddress, mfa_code: felt252) -> bool;
    
    // Profile Management
    fn update_profile(
        ref self: TContractState,
        display_name: felt252,
        email_hash: felt252
    ) -> bool;
    
    fn change_username(ref self: TContractState, new_username: felt252) -> bool;
    
    fn delete_profile(ref self: TContractState) -> bool;
    
    // Admin Functions
    fn transfer_admin(ref self: TContractState, new_admin: starknet::ContractAddress) -> bool;
    
    // Account Recovery
    fn set_recovery_address(ref self: TContractState, recovery_address: starknet::ContractAddress) -> bool;
    fn recover_account(
        ref self: TContractState,
        user_address: starknet::ContractAddress,
        recovery_proof: Array<felt252>
    ) -> bool;
    
    // View Functions
    fn get_user_profile(self: @TContractState, user_address: starknet::ContractAddress) -> UserProfile;
    fn get_user_by_username(self: @TContractState, username: felt252) -> starknet::ContractAddress;
    fn get_session(self: @TContractState, user_address: starknet::ContractAddress) -> Session;
    fn get_nonce(self: @TContractState, user_address: starknet::ContractAddress) -> u64;
    fn is_admin(self: @TContractState, user_address: starknet::ContractAddress) -> bool;
    fn is_mfa_enabled(self: @TContractState, user_address: starknet::ContractAddress) -> bool;
}

#[derive(Drop, Serde, starknet::Store)]
struct UserProfile {
    address: starknet::ContractAddress,
    username: felt252,
    display_name: felt252,
    email_hash: felt252,
    created_at: u64,
    last_login: u64,
    mfa_enabled: bool,
    mfa_secret: felt252,
    failed_login_attempts: u32,
    last_failed_login: u64,
    role: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
struct Session {
    id: felt252,
    user: starknet::ContractAddress,
    status: felt252,
    created_at: u64,
    expires_at: u64,
    last_activity: u64,
    mfa_verified: bool,
    device_info: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
struct UserAuthTypes {
    UserRegistered: Event,
    UserLoggedIn: Event,
    UserLoggedOut: Event,
    SessionExpired: Event,
    SessionRenewed: Event,
    ProfileUpdated: Event,
    UsernameChanged: Event,
    ProfileDeleted: Event,
    AdminRightsTransferred: Event,
    EmergencyRecoverySet: Event,
    EmergencyRecoveryUsed: Event,
    MFAEnabled: Event,
    MFADisabled: Event,
    LoginAttemptFailed: Event,
}