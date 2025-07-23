// -----------------------------------------------------------------------------
// StarkPulse Security Monitor Implementation
// -----------------------------------------------------------------------------
//
// Overview:
// This contract implements comprehensive security monitoring and anomaly detection
// for the StarkPulse ecosystem, providing real-time threat detection and risk assessment.
//
// Features:
// - Real-time transaction anomaly detection
// - Behavioral pattern analysis
// - Risk scoring and assessment
// - Security event logging and alerting
// - Configurable monitoring thresholds
//
// Security Considerations:
// - All security events are immutably logged
// - Risk assessments use multiple factors for accuracy
// - Anomaly detection adapts to user behavior patterns
// - Access controls restrict sensitive operations
// -----------------------------------------------------------------------------

#[starknet::contract]
mod SecurityMonitor {
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp, get_block_number};
    use starknet::storage::Map;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use crate::utils::pausable::Pausable;
    use crate::interfaces::i_security_monitor::ISecurityMonitor;
    
    use contracts::src::interfaces::i_security_monitor::{
        ISecurityMonitor, SecurityEvent, AnomalyScore, TransactionPattern, 
        SecurityAlert, RiskAssessment, SecurityEventLogged, AnomalyDetected,
        SecurityAlertCreated, SecurityAlertResolved, RiskAssessmentUpdated,
        SuspiciousPatternDetected, EVENT_TYPE_SUSPICIOUS_TRANSACTION,
        EVENT_TYPE_UNUSUAL_PATTERN, EVENT_TYPE_HIGH_FREQUENCY, EVENT_TYPE_LARGE_AMOUNT,
        EVENT_TYPE_RAPID_SUCCESSION, RISK_LEVEL_LOW, RISK_LEVEL_MEDIUM, 
        RISK_LEVEL_HIGH, RISK_LEVEL_CRITICAL, PRIORITY_LOW, PRIORITY_MEDIUM,
        PRIORITY_HIGH, PRIORITY_CRITICAL
    };
    use contracts::src::utils::access_control::{AccessControl, IAccessControl};

    // Anomaly detection constants
    const ANOMALY_THRESHOLD_LOW: u256 = 100;
    const ANOMALY_THRESHOLD_MEDIUM: u256 = 500;
    const ANOMALY_THRESHOLD_HIGH: u256 = 1000;
    const ANOMALY_THRESHOLD_CRITICAL: u256 = 2000;
    
    // Pattern analysis constants
    const PATTERN_ANALYSIS_WINDOW: u64 = 86400; // 24 hours in seconds
    const MIN_TRANSACTIONS_FOR_PATTERN: u64 = 5;
    const FREQUENCY_THRESHOLD: u64 = 10; // transactions per hour
    const AMOUNT_DEVIATION_THRESHOLD: u256 = 300; // 300% deviation
    
    // Risk scoring weights
    const WEIGHT_TRANSACTION_RISK: u256 = 40;
    const WEIGHT_BEHAVIORAL_RISK: u256 = 30;
    const WEIGHT_TEMPORAL_RISK: u256 = 30;

    #[storage]
    struct Storage {
        // Security events
        security_events: Map<felt252, SecurityEvent>,
        user_events: Map<ContractAddress, Array<felt252>>,
        event_counter: u64,
        
        // Anomaly scores and patterns
        user_anomaly_scores: Map<ContractAddress, AnomalyScore>,
        user_patterns: Map<(ContractAddress, felt252), TransactionPattern>,
        
        // Security alerts
        security_alerts: Map<felt252, SecurityAlert>,
        user_alerts: Map<ContractAddress, Array<felt252>>,
        alert_counter: u64,
        
        // Risk assessments
        user_risk_assessments: Map<ContractAddress, RiskAssessment>,
        
        // Configuration
        anomaly_thresholds: Map<felt252, u256>,
        monitoring_enabled: Map<(ContractAddress, felt252), bool>,
        
        // Access control
        access_control: IAccessControl,
        admin: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SecurityEventLogged: SecurityEventLogged,
        AnomalyDetected: AnomalyDetected,
        SecurityAlertCreated: SecurityAlertCreated,
        SecurityAlertResolved: SecurityAlertResolved,
        RiskAssessmentUpdated: RiskAssessmentUpdated,
        SuspiciousPatternDetected: SuspiciousPatternDetected,
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin_address: ContractAddress) {
        self.admin.write(admin_address);
        self.event_counter.write(0);
        self.alert_counter.write(0);
        
        // Initialize default thresholds
        self.anomaly_thresholds.write('LOW', ANOMALY_THRESHOLD_LOW);
        self.anomaly_thresholds.write('MEDIUM', ANOMALY_THRESHOLD_MEDIUM);
        self.anomaly_thresholds.write('HIGH', ANOMALY_THRESHOLD_HIGH);
        self.anomaly_thresholds.write('CRITICAL', ANOMALY_THRESHOLD_CRITICAL);
    }

    #[external(v0)]
    impl SecurityMonitorImpl of ISecurityMonitor<ContractState> {
        fn analyze_transaction_anomaly(
            ref self: ContractState,
            user: ContractAddress,
            transaction_hash: felt252,
            tx_type: felt252,
            amount: u256,
            timestamp: u64
        ) -> AnomalyScore {
            // Get existing user pattern
            let pattern = self.user_patterns.read((user, tx_type));
            let mut anomaly_score: u256 = 0;
            let mut risk_factors = ArrayTrait::new();
            
            // Analyze amount deviation
            if pattern.average_amount > 0 {
                let deviation = if amount > pattern.average_amount {
                    (amount - pattern.average_amount) * 100 / pattern.average_amount
                } else {
                    (pattern.average_amount - amount) * 100 / pattern.average_amount
                };
                
                if deviation > AMOUNT_DEVIATION_THRESHOLD {
                    anomaly_score += deviation;
                    risk_factors.append('AMOUNT_DEVIATION');
                }
            }
            
            // Analyze frequency
            let time_since_last = if pattern.last_occurrence > 0 {
                timestamp - pattern.last_occurrence
            } else {
                PATTERN_ANALYSIS_WINDOW
            };
            
            if time_since_last < 3600 && pattern.frequency > FREQUENCY_THRESHOLD {
                anomaly_score += 200;
                risk_factors.append('HIGH_FREQUENCY');
            }
            
            // Analyze temporal patterns
            let hour_of_day = (timestamp % 86400) / 3600;
            if hour_of_day < 6 || hour_of_day > 22 {
                anomaly_score += 50;
                risk_factors.append('UNUSUAL_TIME');
            }
            
            // Determine risk level
            let risk_level = if anomaly_score >= ANOMALY_THRESHOLD_CRITICAL {
                RISK_LEVEL_CRITICAL
            } else if anomaly_score >= ANOMALY_THRESHOLD_HIGH {
                RISK_LEVEL_HIGH
            } else if anomaly_score >= ANOMALY_THRESHOLD_MEDIUM {
                RISK_LEVEL_MEDIUM
            } else {
                RISK_LEVEL_LOW
            };
            
            let anomaly_result = AnomalyScore {
                user: user,
                score: anomaly_score,
                risk_level: risk_level,
                factors: risk_factors,
                last_updated: timestamp,
            };
            
            // Store anomaly score
            self.user_anomaly_scores.write(user, anomaly_result);
            
            // Emit anomaly detection event
            self.emit(AnomalyDetected {
                user: user,
                anomaly_type: tx_type,
                score: anomaly_score,
                risk_level: risk_level,
                timestamp: timestamp,
            });
            
            // Create alert if high risk
            if risk_level == RISK_LEVEL_HIGH || risk_level == RISK_LEVEL_CRITICAL {
                let priority = if risk_level == RISK_LEVEL_CRITICAL { 
                    PRIORITY_CRITICAL 
                } else { 
                    PRIORITY_HIGH 
                };
                
                self.create_security_alert(
                    EVENT_TYPE_SUSPICIOUS_TRANSACTION,
                    priority,
                    user,
                    transaction_hash
                );
            }
            
            anomaly_result
        }
        
        fn update_user_pattern(
            ref self: ContractState,
            user: ContractAddress,
            tx_type: felt252,
            amount: u256,
            timestamp: u64
        ) -> bool {
            let mut pattern = self.user_patterns.read((user, tx_type));
            
            if pattern.user.is_zero() {
                // Create new pattern
                pattern = TransactionPattern {
                    user: user,
                    pattern_type: tx_type,
                    frequency: 1,
                    average_amount: amount,
                    last_occurrence: timestamp,
                    deviation_score: 0,
                };
            } else {
                // Update existing pattern
                pattern.frequency += 1;
                
                // Update average amount using exponential moving average
                let alpha = 20; // 20% weight for new transaction
                pattern.average_amount = (pattern.average_amount * (100 - alpha) + amount * alpha) / 100;
                
                // Calculate time since last transaction
                let time_diff = timestamp - pattern.last_occurrence;
                pattern.last_occurrence = timestamp;
                
                // Update deviation score based on frequency
                if time_diff < 3600 { // Less than 1 hour
                    pattern.deviation_score += 10;
                } else if time_diff > 86400 { // More than 1 day
                    pattern.deviation_score = if pattern.deviation_score > 5 { 
                        pattern.deviation_score - 5 
                    } else { 
                        0 
                    };
                }
            }
            
            self.user_patterns.write((user, tx_type), pattern);
            true
        }
        
        fn get_anomaly_score(
            self: @ContractState,
            user: ContractAddress
        ) -> AnomalyScore {
            self.user_anomaly_scores.read(user)
        }
        
        // Enhanced security events with standardization
        fn log_security_event(
            ref self: ContractState,
            event_type: felt252,
            severity: u8,
            user: ContractAddress,
            transaction_hash: felt252,
            description: felt252,
            metadata: Array<felt252>
        ) -> felt252 {
            let event_id = self.event_counter.read() + 1;
            self.event_counter.write(event_id);
            
            let security_event = SecurityEvent {
                event_id: event_id.into(),
                event_type: event_type,
                severity: severity,
                user: user,
                transaction_hash: transaction_hash,
                timestamp: get_block_timestamp(),
                description: description,
                metadata: metadata,
            };
            
            // Store event
            self.security_events.write(event_id.into(), security_event);
            
            // Add to user's event list
            let mut user_events = self.user_events.read(user);
            user_events.append(event_id.into());
            self.user_events.write(user, user_events);
            
            // Emit event
            self.emit(SecurityEventLogged {
                event_id: event_id.into(),
                event_type: event_type,
                severity: severity,
                user: user,
                timestamp: get_block_timestamp(),
            });
            
            // Generate correlation ID
            let correlation_id = self._generate_correlation_id();
            
            // Emit legacy event
            self.emit(SecurityEventLogged {
                event_id: event_id,
                event_type: event_type,
                severity: severity,
                user: user,
                timestamp: get_block_timestamp(),
            });
            
            // Emit standardized event
            let mut event_data = ArrayTrait::new();
            event_data.append(transaction_hash);
            event_data.append(description);
            event_data.extend(metadata);
            
            let mut indexed_data = ArrayTrait::new();
            indexed_data.append(event_type);
            indexed_data.append(user.into());
            indexed_data.append(severity.into());
            
            self.event_system.read().emit_standard_event(
                'SECURITY_EVENT',
                CATEGORY_SECURITY,
                severity,
                user,
                event_data,
                indexed_data,
                correlation_id
            );
            
            event_id
        }
        
        fn get_security_events(
            self: @ContractState,
            user: ContractAddress,
            event_type: felt252,
            start_time: u64,
            end_time: u64
        ) -> Array<SecurityEvent> {
            let user_event_ids = self.user_events.read(user);
            let mut filtered_events = ArrayTrait::new();
            
            let mut i = 0;
            while i < user_event_ids.len() {
                let event_id = *user_event_ids.at(i);
                let event = self.security_events.read(event_id);
                
                // Apply filters
                let type_match = event_type == 0 || event.event_type == event_type;
                let time_match = event.timestamp >= start_time && event.timestamp <= end_time;
                
                if type_match && time_match {
                    filtered_events.append(event);
                }
                
                i += 1;
            }
            
            filtered_events
        }
        
        fn create_security_alert(
            ref self: ContractState,
            alert_type: felt252,
            priority: u8,
            user: ContractAddress,
            transaction_hash: felt252
        ) -> felt252 {
            let alert_id = self.alert_counter.read() + 1;
            self.alert_counter.write(alert_id);
            
            let alert = SecurityAlert {
                alert_id: alert_id.into(),
                alert_type: alert_type,
                priority: priority,
                user: user,
                transaction_hash: transaction_hash,
                triggered_at: get_block_timestamp(),
                resolved: false,
                resolution_notes: 0,
            };
            
            // Store alert
            self.security_alerts.write(alert_id.into(), alert);
            
            // Add to user's alert list
            let mut user_alerts = self.user_alerts.read(user);
            user_alerts.append(alert_id.into());
            self.user_alerts.write(user, user_alerts);
            
            // Emit event
            self.emit(SecurityAlertCreated {
                alert_id: alert_id.into(),
                alert_type: alert_type,
                priority: priority,
                user: user,
                timestamp: get_block_timestamp(),
            });
            
            alert_id.into()
        }
        
        fn resolve_security_alert(
            ref self: ContractState,
            alert_id: felt252,
            resolution_notes: felt252
        ) -> bool {
            let caller = get_caller_address();
            
            // Only admin can resolve alerts
            assert(caller == self.admin.read(), "Only admin can resolve alerts");
            
            let mut alert = self.security_alerts.read(alert_id);
            assert(alert.alert_id != 0, "Alert does not exist");
            assert(!alert.resolved, "Alert already resolved");
            
            alert.resolved = true;
            alert.resolution_notes = resolution_notes;
            self.security_alerts.write(alert_id, alert);
            
            // Emit event
            self.emit(SecurityAlertResolved {
                alert_id: alert_id,
                resolved_by: caller,
                timestamp: get_block_timestamp(),
            });
            
            true
        }
        
        fn get_active_alerts(
            self: @ContractState,
            user: ContractAddress
        ) -> Array<SecurityAlert> {
            let user_alert_ids = self.user_alerts.read(user);
            let mut active_alerts = ArrayTrait::new();
            
            let mut i = 0;
            while i < user_alert_ids.len() {
                let alert_id = *user_alert_ids.at(i);
                let alert = self.security_alerts.read(alert_id);
                
                if !alert.resolved {
                    active_alerts.append(alert);
                }
                
                i += 1;
            }
            
            active_alerts
        }
        
        fn assess_transaction_risk(
            self: @ContractState,
            user: ContractAddress,
            tx_type: felt252,
            amount: u256,
            timestamp: u64
        ) -> RiskAssessment {
            // Get current anomaly score
            let anomaly = self.user_anomaly_scores.read(user);
            
            // Calculate transaction risk based on amount and type
            let transaction_risk = if amount > 1000000000000000000000 { // > 1000 tokens
                500
            } else if amount > 100000000000000000000 { // > 100 tokens
                200
            } else {
                50
            };
            
            // Calculate behavioral risk based on patterns
            let pattern = self.user_patterns.read((user, tx_type));
            let behavioral_risk = pattern.deviation_score * 10;
            
            // Calculate temporal risk based on time of day
            let hour_of_day = (timestamp % 86400) / 3600;
            let temporal_risk = if hour_of_day < 6 || hour_of_day > 22 {
                100
            } else {
                20
            };
            
            // Calculate overall risk score
            let overall_risk = (
                transaction_risk * WEIGHT_TRANSACTION_RISK +
                behavioral_risk * WEIGHT_BEHAVIORAL_RISK +
                temporal_risk * WEIGHT_TEMPORAL_RISK
            ) / 100;
            
            RiskAssessment {
                user: user,
                overall_risk_score: overall_risk,
                transaction_risk: transaction_risk,
                behavioral_risk: behavioral_risk,
                temporal_risk: temporal_risk,
                assessment_timestamp: timestamp,
            }
        }
        
        fn get_user_risk_profile(
            self: @ContractState,
            user: ContractAddress
        ) -> RiskAssessment {
            self.user_risk_assessments.read(user)
        }
        
        fn analyze_transaction_patterns(
            ref self: ContractState,
            user: ContractAddress,
            lookback_period: u64
        ) -> Array<TransactionPattern> {
            // This would analyze patterns over the lookback period
            // For now, return stored patterns
            let mut patterns = ArrayTrait::new();
            
            // In a full implementation, we would iterate through transaction types
            // and return patterns for each type within the lookback period
            
            patterns
        }
        
        fn detect_suspicious_patterns(
            self: @ContractState,
            user: ContractAddress,
            pattern_types: Array<felt252>
        ) -> Array<felt252> {
            let mut suspicious_patterns = ArrayTrait::new();
            
            let mut i = 0;
            while i < pattern_types.len() {
                let pattern_type = *pattern_types.at(i);
                let pattern = self.user_patterns.read((user, pattern_type));
                
                // Check for suspicious indicators
                if pattern.frequency > FREQUENCY_THRESHOLD {
                    suspicious_patterns.append('HIGH_FREQUENCY');
                }
                
                if pattern.deviation_score > 100 {
                    suspicious_patterns.append('HIGH_DEVIATION');
                }
                
                i += 1;
            }
            
            suspicious_patterns
        }
        
        fn set_anomaly_threshold(
            ref self: ContractState,
            threshold_type: felt252,
            threshold_value: u256
        ) -> bool {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), "Only admin can set thresholds");
            
            self.anomaly_thresholds.write(threshold_type, threshold_value);
            true
        }
        
        fn get_anomaly_threshold(
            self: @ContractState,
            threshold_type: felt252
        ) -> u256 {
            self.anomaly_thresholds.read(threshold_type)
        }
        
        fn enable_monitoring(
            ref self: ContractState,
            user: ContractAddress,
            monitoring_types: Array<felt252>
        ) -> bool {
            let mut i = 0;
            while i < monitoring_types.len() {
                let monitoring_type = *monitoring_types.at(i);
                self.monitoring_enabled.write((user, monitoring_type), true);
                i += 1;
            }
            true
        }
        
        fn disable_monitoring(
            ref self: ContractState,
            user: ContractAddress,
            monitoring_types: Array<felt252>
        ) -> bool {
            let mut i = 0;
            while i < monitoring_types.len() {
                let monitoring_type = *monitoring_types.at(i);
                self.monitoring_enabled.write((user, monitoring_type), false);
                i += 1;
            }
            true
        }
        
        fn is_monitoring_enabled(
            self: @ContractState,
            user: ContractAddress,
            monitoring_type: felt252
        ) -> bool {
            self.monitoring_enabled.read((user, monitoring_type))
        }
        
        fn generate_security_report(
            self: @ContractState,
            user: ContractAddress,
            report_type: felt252,
            start_time: u64,
            end_time: u64
        ) -> Array<felt252> {
            // Generate security report data
            let mut report_data = ArrayTrait::new();
            
            // Add basic metrics
            let anomaly_score = self.user_anomaly_scores.read(user);
            report_data.append(anomaly_score.score.low.into());
            report_data.append(anomaly_score.score.high.into());
            
            report_data
        }
        
        fn get_security_metrics(
            self: @ContractState,
            metric_type: felt252,
            time_period: u64
        ) -> Array<u256> {
            // Return security metrics for the specified type and period
            let mut metrics = ArrayTrait::new();
            
            // Add placeholder metrics
            metrics.append(100);
            metrics.append(200);
            
            metrics
        }


        #[only_role('AUTO_PAUSER')]
        fn check_and_pause(
            self: @ContractState,
            target: ContractAddress,
            anomaly_score: u8
        ) -> bool {
            if anomaly_score > 80 {
                let pausable = IPausableDispatcher { contract_address: target };
                pausable.pause();
                return true;
            }
            false
        }
    }
}
