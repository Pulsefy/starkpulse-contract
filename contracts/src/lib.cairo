// StarkPulse Contract - Library File
// Exports all project modules

// Interface modules
mod interfaces {
    pub mod i_erc20;
    pub mod i_token_vesting;
    pub mod i_transaction_monitor;
    pub mod i_portfolio_tracker;
    pub mod i_error_handling;
    pub mod i_upgradeable;
    pub mod i_security_monitor;
}

// Utility modules
mod utils {
    pub mod access_control;
    pub mod error_handling;
    pub mod crypto_utils;
    pub mod security_monitor;
}

// Proxy modules
mod upgradeable {
    pub mod upgradeable;
}

// Main modules
mod vesting {
    pub mod TokenVesting;
}

// Tests
#[cfg(test)]
mod tests {
    pub mod test_token_vesting;
    pub mod test_user_auth;
    pub mod test_contract_interaction;
    pub mod test_erc20_token;
    pub mod test_starkpulse_token;
    pub mod test_access_control;
    pub mod test_event_emission;
    pub mod test_transaction_security;
    pub mod test_anomaly_detection;
}
