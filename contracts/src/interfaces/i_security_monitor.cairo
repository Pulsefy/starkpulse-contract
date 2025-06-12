// -----------------------------------------------------------------------------
// StarkPulse Security Monitor Interface
// -----------------------------------------------------------------------------
//
// Overview:
// This interface defines the security monitoring and anomaly detection
// capabilities for the StarkPulse ecosystem.
//
// Features:
// - Real-time anomaly detection
// - Transaction pattern analysis
// - Suspicious activity flagging
// - Security event logging
// - Risk assessment and scoring
// -----------------------------------------------------------------------------

use starknet::ContractAddress;
use array::ArrayTrait;

#[derive(Drop, Serde, starknet::Store)]
struct SecurityEvent {
    event_id: felt252,
    event_type: felt252,
    severity: u8,
    user: ContractAddress,
    transaction_hash: felt252,
    timestamp: u64,
    description: felt252,
    metadata: Array<felt252>,
}

#[derive(Drop, Serde, starknet::Store)]
struct AnomalyScore {
    user: ContractAddress,
    score: u256,
    risk_level: felt252,
    factors: Array<felt252>,
    last_updated: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct TransactionPattern {
    user: ContractAddress,
    pattern_type: felt252,
    frequency: u64,
    average_amount: u256,
    last_occurrence: u64,
    deviation_score: u256,
}

#[derive(Drop, Serde, starknet::Store)]
struct SecurityAlert {
    alert_id: felt252,
    alert_type: felt252,
    priority: u8,
    user: ContractAddress,
    transaction_hash: felt252,
    triggered_at: u64,
    resolved: bool,
    resolution_notes: felt252,
}

#[derive(Drop, Serde, starknet::Store)]
struct RiskAssessment {
    user: ContractAddress,
    overall_risk_score: u256,
    transaction_risk: u256,
    behavioral_risk: u256,
    temporal_risk: u256,
    assessment_timestamp: u64,
}

// Security event types
const EVENT_TYPE_SUSPICIOUS_TRANSACTION: felt252 = 'SUSPICIOUS_TX';
const EVENT_TYPE_UNUSUAL_PATTERN: felt252 = 'UNUSUAL_PATTERN';
const EVENT_TYPE_HIGH_FREQUENCY: felt252 = 'HIGH_FREQUENCY';
const EVENT_TYPE_LARGE_AMOUNT: felt252 = 'LARGE_AMOUNT';
const EVENT_TYPE_RAPID_SUCCESSION: felt252 = 'RAPID_SUCCESSION';
const EVENT_TYPE_UNAUTHORIZED_ACCESS: felt252 = 'UNAUTHORIZED_ACCESS';

// Risk levels
const RISK_LEVEL_LOW: felt252 = 'LOW';
const RISK_LEVEL_MEDIUM: felt252 = 'MEDIUM';
const RISK_LEVEL_HIGH: felt252 = 'HIGH';
const RISK_LEVEL_CRITICAL: felt252 = 'CRITICAL';

// Alert priorities
const PRIORITY_LOW: u8 = 1;
const PRIORITY_MEDIUM: u8 = 2;
const PRIORITY_HIGH: u8 = 3;
const PRIORITY_CRITICAL: u8 = 4;

#[starknet::interface]
trait ISecurityMonitor<TContractState> {
    // Anomaly Detection
    fn analyze_transaction_anomaly(
        ref self: TContractState,
        user: ContractAddress,
        transaction_hash: felt252,
        tx_type: felt252,
        amount: u256,
        timestamp: u64
    ) -> AnomalyScore;
    
    fn update_user_pattern(
        ref self: TContractState,
        user: ContractAddress,
        tx_type: felt252,
        amount: u256,
        timestamp: u64
    ) -> bool;
    
    fn get_anomaly_score(
        self: @TContractState,
        user: ContractAddress
    ) -> AnomalyScore;
    
    // Security Event Management
    fn log_security_event(
        ref self: TContractState,
        event_type: felt252,
        severity: u8,
        user: ContractAddress,
        transaction_hash: felt252,
        description: felt252,
        metadata: Array<felt252>
    ) -> felt252;
    
    fn get_security_events(
        self: @TContractState,
        user: ContractAddress,
        event_type: felt252,
        start_time: u64,
        end_time: u64
    ) -> Array<SecurityEvent>;
    
    // Alert Management
    fn create_security_alert(
        ref self: TContractState,
        alert_type: felt252,
        priority: u8,
        user: ContractAddress,
        transaction_hash: felt252
    ) -> felt252;
    
    fn resolve_security_alert(
        ref self: TContractState,
        alert_id: felt252,
        resolution_notes: felt252
    ) -> bool;
    
    fn get_active_alerts(
        self: @TContractState,
        user: ContractAddress
    ) -> Array<SecurityAlert>;
    
    // Risk Assessment
    fn assess_transaction_risk(
        self: @TContractState,
        user: ContractAddress,
        tx_type: felt252,
        amount: u256,
        timestamp: u64
    ) -> RiskAssessment;
    
    fn get_user_risk_profile(
        self: @TContractState,
        user: ContractAddress
    ) -> RiskAssessment;
    
    // Pattern Analysis
    fn analyze_transaction_patterns(
        ref self: TContractState,
        user: ContractAddress,
        lookback_period: u64
    ) -> Array<TransactionPattern>;
    
    fn detect_suspicious_patterns(
        self: @TContractState,
        user: ContractAddress,
        pattern_types: Array<felt252>
    ) -> Array<felt252>;
    
    // Threshold Management
    fn set_anomaly_threshold(
        ref self: TContractState,
        threshold_type: felt252,
        threshold_value: u256
    ) -> bool;
    
    fn get_anomaly_threshold(
        self: @TContractState,
        threshold_type: felt252
    ) -> u256;
    
    // Security Configuration
    fn enable_monitoring(
        ref self: TContractState,
        user: ContractAddress,
        monitoring_types: Array<felt252>
    ) -> bool;
    
    fn disable_monitoring(
        ref self: TContractState,
        user: ContractAddress,
        monitoring_types: Array<felt252>
    ) -> bool;
    
    fn is_monitoring_enabled(
        self: @TContractState,
        user: ContractAddress,
        monitoring_type: felt252
    ) -> bool;
    
    // Reporting and Analytics
    fn generate_security_report(
        self: @TContractState,
        user: ContractAddress,
        report_type: felt252,
        start_time: u64,
        end_time: u64
    ) -> Array<felt252>;
    
    fn get_security_metrics(
        self: @TContractState,
        metric_type: felt252,
        time_period: u64
    ) -> Array<u256>;
}

// Security Monitor Event Types
#[derive(Drop, starknet::Event)]
struct SecurityEventLogged {
    event_id: felt252,
    event_type: felt252,
    severity: u8,
    user: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct AnomalyDetected {
    user: ContractAddress,
    anomaly_type: felt252,
    score: u256,
    risk_level: felt252,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct SecurityAlertCreated {
    alert_id: felt252,
    alert_type: felt252,
    priority: u8,
    user: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct SecurityAlertResolved {
    alert_id: felt252,
    resolved_by: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct RiskAssessmentUpdated {
    user: ContractAddress,
    old_risk_score: u256,
    new_risk_score: u256,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct SuspiciousPatternDetected {
    user: ContractAddress,
    pattern_type: felt252,
    confidence_score: u256,
    timestamp: u64,
}
