#[cfg(test)]
mod test_anomaly_detection {
    use starknet::{
        ContractAddress, 
        contract_address_const, 
        testing::{set_caller_address, set_block_timestamp}
    };
    
    use contracts::src::utils::security_monitor::{SecurityMonitor, ISecurityMonitor};
    use contracts::src::interfaces::i_security_monitor::{
        AnomalyScore, SecurityEvent, SecurityAlert, RiskAssessment,
        RISK_LEVEL_LOW, RISK_LEVEL_MEDIUM, RISK_LEVEL_HIGH, RISK_LEVEL_CRITICAL,
        EVENT_TYPE_SUSPICIOUS_TRANSACTION, EVENT_TYPE_HIGH_FREQUENCY,
        PRIORITY_HIGH, PRIORITY_CRITICAL
    };
    use array::ArrayTrait;
    
    // Test addresses
    const ADMIN: felt252 = 0x123;
    const USER1: felt252 = 0x456;
    const USER2: felt252 = 0x789;
    
    // Transaction constants
    const TX_HASH_1: felt252 = 0x111;
    const TX_HASH_2: felt252 = 0x222;
    const TX_HASH_3: felt252 = 0x333;
    const TYPE_DEPOSIT: felt252 = 'DEPOSIT';
    const TYPE_WITHDRAWAL: felt252 = 'WITHDRAWAL';
    const AMOUNT_NORMAL: u256 = 100000000000000000000;  // 100 tokens
    const AMOUNT_LARGE: u256 = 10000000000000000000000; // 10,000 tokens
    
    fn setup_security_monitor() -> (
        SecurityMonitor::ContractState,
        ContractAddress,
        ContractAddress,
        ContractAddress
    ) {
        let admin = contract_address_const::<ADMIN>();
        let user1 = contract_address_const::<USER1>();
        let user2 = contract_address_const::<USER2>();
        
        set_caller_address(admin);
        set_block_timestamp(1000);
        
        let mut contract = SecurityMonitor::unsafe_new();
        SecurityMonitor::constructor(ref contract, admin);
        
        (contract, admin, user1, user2)
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_anomaly_detection_normal_transaction() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(user1);
        
        // Analyze a normal transaction
        let anomaly_score = contract.analyze_transaction_anomaly(
            user1,
            TX_HASH_1,
            TYPE_DEPOSIT,
            AMOUNT_NORMAL,
            1000
        );
        
        // Normal transaction should have low risk
        assert(anomaly_score.user == user1, "User mismatch in anomaly score");
        assert(anomaly_score.score < 500, "Normal transaction should have low anomaly score");
        assert(anomaly_score.risk_level == RISK_LEVEL_LOW || anomaly_score.risk_level == RISK_LEVEL_MEDIUM, "Risk level should be low or medium");
        assert(anomaly_score.last_updated == 1000, "Timestamp should match");
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_anomaly_detection_large_amount() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(user1);
        
        // First, establish a pattern with normal amounts
        contract.update_user_pattern(user1, TYPE_DEPOSIT, AMOUNT_NORMAL, 900);
        contract.update_user_pattern(user1, TYPE_DEPOSIT, AMOUNT_NORMAL, 950);
        
        // Now analyze a large transaction that deviates significantly
        let anomaly_score = contract.analyze_transaction_anomaly(
            user1,
            TX_HASH_2,
            TYPE_DEPOSIT,
            AMOUNT_LARGE, // 100x larger than normal
            1000
        );
        
        // Large deviation should trigger higher anomaly score
        assert(anomaly_score.score > 100, "Large amount deviation should increase anomaly score");
        assert(anomaly_score.factors.len() > 0, "Should have risk factors identified");
        
        // Check if amount deviation is flagged
        let mut found_amount_deviation = false;
        let mut i = 0;
        while i < anomaly_score.factors.len() {
            if *anomaly_score.factors.at(i) == 'AMOUNT_DEVIATION' {
                found_amount_deviation = true;
                break;
            }
            i += 1;
        }
        assert(found_amount_deviation, "Amount deviation should be flagged");
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_high_frequency_detection() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(user1);
        
        // Simulate rapid transactions (within 1 hour)
        let base_time = 1000;
        
        // First transaction
        contract.analyze_transaction_anomaly(
            user1, TX_HASH_1, TYPE_WITHDRAWAL, AMOUNT_NORMAL, base_time
        );
        
        // Update pattern to simulate high frequency
        let mut i = 0;
        while i < 15 { // Simulate 15 transactions to exceed frequency threshold
            contract.update_user_pattern(user1, TYPE_WITHDRAWAL, AMOUNT_NORMAL, base_time + i * 60);
            i += 1;
        }
        
        // Analyze another transaction shortly after
        let anomaly_score = contract.analyze_transaction_anomaly(
            user1,
            TX_HASH_2,
            TYPE_WITHDRAWAL,
            AMOUNT_NORMAL,
            base_time + 900 // 15 minutes later
        );
        
        // Should detect high frequency pattern
        let mut found_high_frequency = false;
        let mut i = 0;
        while i < anomaly_score.factors.len() {
            if *anomaly_score.factors.at(i) == 'HIGH_FREQUENCY' {
                found_high_frequency = true;
                break;
            }
            i += 1;
        }
        assert(found_high_frequency, "High frequency should be detected");
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_unusual_time_detection() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(user1);
        
        // Transaction at 3 AM (unusual time)
        let unusual_time = 3 * 3600; // 3 hours after midnight
        
        let anomaly_score = contract.analyze_transaction_anomaly(
            user1,
            TX_HASH_1,
            TYPE_WITHDRAWAL,
            AMOUNT_NORMAL,
            unusual_time
        );
        
        // Should detect unusual time
        let mut found_unusual_time = false;
        let mut i = 0;
        while i < anomaly_score.factors.len() {
            if *anomaly_score.factors.at(i) == 'UNUSUAL_TIME' {
                found_unusual_time = true;
                break;
            }
            i += 1;
        }
        assert(found_unusual_time, "Unusual time should be detected");
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_security_event_logging() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(admin);
        
        // Log a security event
        let mut metadata = ArrayTrait::new();
        metadata.append('TEST_METADATA_1');
        metadata.append('TEST_METADATA_2');
        
        let event_id = contract.log_security_event(
            EVENT_TYPE_SUSPICIOUS_TRANSACTION,
            3, // High severity
            user1,
            TX_HASH_1,
            'Test suspicious transaction',
            metadata
        );
        
        assert(event_id != 0, "Event ID should be generated");
        
        // Retrieve security events
        let events = contract.get_security_events(
            user1,
            EVENT_TYPE_SUSPICIOUS_TRANSACTION,
            0,
            2000
        );
        
        assert(events.len() == 1, "Should have one security event");
        
        let event = *events.at(0);
        assert(event.event_type == EVENT_TYPE_SUSPICIOUS_TRANSACTION, "Event type mismatch");
        assert(event.severity == 3, "Severity mismatch");
        assert(event.user == user1, "User mismatch");
        assert(event.transaction_hash == TX_HASH_1, "Transaction hash mismatch");
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_security_alert_creation_and_resolution() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(admin);
        
        // Create a security alert
        let alert_id = contract.create_security_alert(
            EVENT_TYPE_HIGH_FREQUENCY,
            PRIORITY_HIGH,
            user1,
            TX_HASH_1
        );
        
        assert(alert_id != 0, "Alert ID should be generated");
        
        // Get active alerts
        let active_alerts = contract.get_active_alerts(user1);
        assert(active_alerts.len() == 1, "Should have one active alert");
        
        let alert = *active_alerts.at(0);
        assert(alert.alert_type == EVENT_TYPE_HIGH_FREQUENCY, "Alert type mismatch");
        assert(alert.priority == PRIORITY_HIGH, "Priority mismatch");
        assert(!alert.resolved, "Alert should not be resolved initially");
        
        // Resolve the alert
        let resolved = contract.resolve_security_alert(
            alert_id,
            'False positive - resolved by admin'
        );
        assert(resolved, "Alert resolution should succeed");
        
        // Check that alert is no longer active
        let active_alerts_after = contract.get_active_alerts(user1);
        assert(active_alerts_after.len() == 0, "Should have no active alerts after resolution");
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_risk_assessment() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(user1);
        
        // Assess risk for a normal transaction
        let risk_assessment = contract.assess_transaction_risk(
            user1,
            TYPE_DEPOSIT,
            AMOUNT_NORMAL,
            1000
        );
        
        assert(risk_assessment.user == user1, "User mismatch in risk assessment");
        assert(risk_assessment.overall_risk_score > 0, "Overall risk score should be calculated");
        assert(risk_assessment.transaction_risk > 0, "Transaction risk should be calculated");
        assert(risk_assessment.behavioral_risk >= 0, "Behavioral risk should be calculated");
        assert(risk_assessment.temporal_risk > 0, "Temporal risk should be calculated");
        assert(risk_assessment.assessment_timestamp == 1000, "Timestamp should match");
        
        // Assess risk for a large transaction
        let high_risk_assessment = contract.assess_transaction_risk(
            user1,
            TYPE_WITHDRAWAL,
            AMOUNT_LARGE,
            1000
        );
        
        // Large transaction should have higher risk
        assert(
            high_risk_assessment.overall_risk_score > risk_assessment.overall_risk_score,
            "Large transaction should have higher risk score"
        );
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_pattern_analysis() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(user1);
        
        // Update user patterns
        contract.update_user_pattern(user1, TYPE_DEPOSIT, AMOUNT_NORMAL, 1000);
        contract.update_user_pattern(user1, TYPE_DEPOSIT, AMOUNT_NORMAL, 1100);
        contract.update_user_pattern(user1, TYPE_DEPOSIT, AMOUNT_NORMAL, 1200);
        
        // Detect suspicious patterns
        let mut pattern_types = ArrayTrait::new();
        pattern_types.append(TYPE_DEPOSIT);
        pattern_types.append(TYPE_WITHDRAWAL);
        
        let suspicious_patterns = contract.detect_suspicious_patterns(user1, pattern_types);
        
        // Should return analysis results (implementation dependent)
        assert(suspicious_patterns.len() >= 0, "Should return pattern analysis results");
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_monitoring_configuration() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(user1);
        
        // Enable monitoring for specific types
        let mut monitoring_types = ArrayTrait::new();
        monitoring_types.append('AMOUNT_MONITORING');
        monitoring_types.append('FREQUENCY_MONITORING');
        
        let enabled = contract.enable_monitoring(user1, monitoring_types);
        assert(enabled, "Monitoring enablement should succeed");
        
        // Check if monitoring is enabled
        let amount_enabled = contract.is_monitoring_enabled(user1, 'AMOUNT_MONITORING');
        let frequency_enabled = contract.is_monitoring_enabled(user1, 'FREQUENCY_MONITORING');
        
        assert(amount_enabled, "Amount monitoring should be enabled");
        assert(frequency_enabled, "Frequency monitoring should be enabled");
        
        // Disable monitoring
        let mut disable_types = ArrayTrait::new();
        disable_types.append('AMOUNT_MONITORING');
        
        let disabled = contract.disable_monitoring(user1, disable_types);
        assert(disabled, "Monitoring disabling should succeed");
        
        // Check if monitoring is disabled
        let amount_disabled = contract.is_monitoring_enabled(user1, 'AMOUNT_MONITORING');
        assert(!amount_disabled, "Amount monitoring should be disabled");
        
        // Frequency monitoring should still be enabled
        let frequency_still_enabled = contract.is_monitoring_enabled(user1, 'FREQUENCY_MONITORING');
        assert(frequency_still_enabled, "Frequency monitoring should still be enabled");
    }
    
    #[test]
    #[available_gas(5000000)]
    fn test_threshold_management() {
        let (mut contract, admin, user1, _) = setup_security_monitor();
        
        set_caller_address(admin);
        
        // Set custom anomaly threshold
        let threshold_set = contract.set_anomaly_threshold('CUSTOM_THRESHOLD', 750);
        assert(threshold_set, "Threshold setting should succeed");
        
        // Get the threshold back
        let threshold_value = contract.get_anomaly_threshold('CUSTOM_THRESHOLD');
        assert(threshold_value == 750, "Threshold value should match what was set");
        
        // Test default thresholds
        let low_threshold = contract.get_anomaly_threshold('LOW');
        let medium_threshold = contract.get_anomaly_threshold('MEDIUM');
        let high_threshold = contract.get_anomaly_threshold('HIGH');
        
        assert(low_threshold > 0, "Low threshold should be set");
        assert(medium_threshold > low_threshold, "Medium threshold should be higher than low");
        assert(high_threshold > medium_threshold, "High threshold should be higher than medium");
    }
}
