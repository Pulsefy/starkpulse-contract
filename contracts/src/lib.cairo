// StarkPulse Contract - Library File
// Exports all project modules

// Interface modules
mod interfaces {
    pub mod i_erc20;
    pub mod i_token_vesting;
    pub mod i_transaction_monitor;
    pub mod i_portfolio_tracker;
    pub mod i_error_handling;
}

// Utility modules
mod utils {
    pub mod access_control;
    pub mod error_handling;
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
}
