#[starknet::interface]
trait IUserAuth<TContractState> {
    // User Registration
    fn register_user(
        ref self: TContractState,
        username: felt252,
        display_name: felt252,
        email_hash: felt252
    ) -> bool;
    
    // Login/Logout
    fn login(
        ref self: TContractState,
        signature: Array<felt252>,
        message_hash: felt252,
        nonce: u64
    ) -> felt252;
    
    fn logout(ref self: TContractState) -> bool;
    
    // Session Management
    fn validate_session(self: @TContractState, user_address: starknet::ContractAddress) -> bool;
    
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
    
    fn recover_account(ref self: TContractState, user_address: starknet::ContractAddress) -> bool;

    // Contract Pause/Resume
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    
    // View Functions
    fn get_user_profile(self: @TContractState, user_address: starknet::ContractAddress) -> UserProfile;
    
    fn get_user_by_username(self: @TContractState, username: felt252) -> starknet::ContractAddress;
    
    fn get_session(self: @TContractState, user_address: starknet::ContractAddress) -> Session;
    
    fn get_nonce(self: @TContractState, user_address: starknet::ContractAddress) -> u64;
    
    fn is_admin(self: @TContractState, user_address: starknet::ContractAddress) -> bool;
    
}

#[derive(Drop, Serde, starknet::Store)]
struct UserProfile {
    address: starknet::ContractAddress,
    username: felt252,
    display_name: felt252,
    email_hash: felt252,
    created_at: u64,
    last_login: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct Session {
    id: felt252,
    user: starknet::ContractAddress,
    status: felt252,
    created_at: u64,
    expires_at: u64,
    last_activity: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct UserAuthTypes {
    UserRegistered: Event,
    UserLoggedIn: Event,
    UserLoggedOut: Event,
    SessionExpired: Event,
    ProfileUpdated: Event,
    UsernameChanged: Event,
    ProfileDeleted: Event,
    AdminRightsTransferred: Event,
    EmergencyRecoverySet: Event,
    EmergencyRecoveryUsed: Event,
}