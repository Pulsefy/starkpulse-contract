# 🌐 StarkPulse Frontend Security Integration Guide

## Overview

This guide provides comprehensive instructions for integrating the enhanced security features of the StarkPulse transaction monitoring system into frontend applications.

## 🚀 Quick Start

### Installation

```bash
# Install StarkNet.js for contract interaction
npm install starknet

# Install additional security utilities
npm install @starknet-io/get-starknet
npm install crypto-js
npm install web3-utils
```

### Basic Setup

```typescript
import { Contract, Provider, Account } from 'starknet';

// Initialize provider
const provider = new Provider({
  sequencer: { network: 'testnet' } // or 'mainnet'
});

// Contract addresses (from deployment)
const TRANSACTION_MONITOR_ADDRESS = '0x...';
const SECURITY_MONITOR_ADDRESS = '0x...';
const ACCESS_CONTROL_ADDRESS = '0x...';

// Initialize contracts
const transactionMonitor = new Contract(
  transactionMonitorAbi,
  TRANSACTION_MONITOR_ADDRESS,
  provider
);

const securityMonitor = new Contract(
  securityMonitorAbi,
  SECURITY_MONITOR_ADDRESS,
  provider
);
```

## 🔒 Security Features Integration

### Transaction Recording with Security

```typescript
interface SecureTransactionData {
  txHash: string;
  txType: string;
  amount: string;
  description: string;
  userAddress: string;
}

class SecureTransactionManager {
  private transactionMonitor: Contract;
  private securityMonitor: Contract;
  private account: Account;

  constructor(contracts: any, account: Account) {
    this.transactionMonitor = contracts.transactionMonitor;
    this.securityMonitor = contracts.securityMonitor;
    this.account = account;
  }

  async recordSecureTransaction(data: SecureTransactionData): Promise<{
    success: boolean;
    txHash: string;
    securityScore: number;
    alerts: any[];
  }> {
    try {
      // Step 1: Record transaction with security features
      const recordResult = await this.transactionMonitor.invoke(
        'record_transaction',
        [data.txHash, data.txType, data.amount, data.description],
        { account: this.account }
      );

      // Step 2: Get real-time security analysis
      const securityAnalysis = await this.securityMonitor.call(
        'analyze_transaction_anomaly',
        [
          data.userAddress,
          data.txHash,
          data.txType,
          data.amount,
          Math.floor(Date.now() / 1000)
        ]
      );

      // Step 3: Check for security alerts
      const activeAlerts = await this.securityMonitor.call(
        'get_active_alerts',
        [data.userAddress]
      );

      return {
        success: true,
        txHash: recordResult.transaction_hash,
        securityScore: parseInt(securityAnalysis.score),
        alerts: activeAlerts
      };

    } catch (error) {
      console.error('Secure transaction recording failed:', error);
      throw new Error(`Transaction recording failed: ${error.message}`);
    }
  }

  async verifyTransactionIntegrity(txHash: string): Promise<boolean> {
    try {
      const signature = await this.generateTransactionSignature(txHash);
      
      const verificationResult = await this.transactionMonitor.call(
        'verify_transaction_integrity',
        [txHash, signature]
      );

      return verificationResult === 1; // Cairo returns 1 for true
    } catch (error) {
      console.error('Integrity verification failed:', error);
      return false;
    }
  }

  private async generateTransactionSignature(txHash: string): Promise<string[]> {
    // Simplified signature generation - in production use proper cryptographic signing
    const timestamp = Math.floor(Date.now() / 1000);
    return [
      `0x${timestamp.toString(16)}`,
      `0x${(timestamp * 2).toString(16)}`
    ];
  }
}
```

### Real-Time Security Monitoring

```typescript
class SecurityMonitoringService {
  private securityMonitor: Contract;
  private eventListeners: Map<string, Function[]> = new Map();

  constructor(securityMonitor: Contract) {
    this.securityMonitor = securityMonitor;
    this.startEventListening();
  }

  // Subscribe to security events
  onSecurityEvent(eventType: string, callback: Function): void {
    if (!this.eventListeners.has(eventType)) {
      this.eventListeners.set(eventType, []);
    }
    this.eventListeners.get(eventType)!.push(callback);
  }

  // Get user's current risk assessment
  async getUserRiskAssessment(userAddress: string): Promise<{
    overallRisk: number;
    riskLevel: string;
    factors: string[];
    lastUpdated: number;
  }> {
    try {
      const riskData = await this.securityMonitor.call(
        'get_user_risk_profile',
        [userAddress]
      );

      return {
        overallRisk: parseInt(riskData.overall_risk_score),
        riskLevel: this.getRiskLevelString(riskData.overall_risk_score),
        factors: riskData.risk_factors || [],
        lastUpdated: parseInt(riskData.assessment_timestamp)
      };
    } catch (error) {
      console.error('Risk assessment failed:', error);
      throw error;
    }
  }

  // Get security alerts for user
  async getUserSecurityAlerts(userAddress: string): Promise<any[]> {
    try {
      const alerts = await this.securityMonitor.call(
        'get_active_alerts',
        [userAddress]
      );

      return alerts.map((alert: any) => ({
        id: alert.alert_id,
        type: alert.alert_type,
        priority: this.getPriorityString(alert.priority),
        timestamp: new Date(parseInt(alert.triggered_at) * 1000),
        resolved: alert.resolved
      }));
    } catch (error) {
      console.error('Failed to get security alerts:', error);
      return [];
    }
  }

  private startEventListening(): void {
    // In a real implementation, this would use WebSocket or polling
    // to listen for contract events
    setInterval(async () => {
      await this.pollForEvents();
    }, 5000); // Poll every 5 seconds
  }

  private async pollForEvents(): void {
    // Simplified event polling - in production use proper event filtering
    try {
      // This would be implemented with proper event filtering
      // based on the specific StarkNet event system
    } catch (error) {
      console.error('Event polling failed:', error);
    }
  }

  private getRiskLevelString(score: number): string {
    if (score >= 2000) return 'CRITICAL';
    if (score >= 1000) return 'HIGH';
    if (score >= 500) return 'MEDIUM';
    return 'LOW';
  }

  private getPriorityString(priority: number): string {
    switch (priority) {
      case 4: return 'CRITICAL';
      case 3: return 'HIGH';
      case 2: return 'MEDIUM';
      case 1: return 'LOW';
      default: return 'UNKNOWN';
    }
  }
}
```

### Security Dashboard Components

```typescript
// React component for security dashboard
import React, { useState, useEffect } from 'react';

interface SecurityDashboardProps {
  userAddress: string;
  securityService: SecurityMonitoringService;
}

const SecurityDashboard: React.FC<SecurityDashboardProps> = ({
  userAddress,
  securityService
}) => {
  const [riskAssessment, setRiskAssessment] = useState<any>(null);
  const [securityAlerts, setSecurityAlerts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadSecurityData();
    
    // Subscribe to real-time security events
    securityService.onSecurityEvent('ANOMALY_DETECTED', handleAnomalyDetected);
    securityService.onSecurityEvent('ALERT_CREATED', handleAlertCreated);
  }, [userAddress]);

  const loadSecurityData = async () => {
    try {
      setLoading(true);
      
      const [risk, alerts] = await Promise.all([
        securityService.getUserRiskAssessment(userAddress),
        securityService.getUserSecurityAlerts(userAddress)
      ]);
      
      setRiskAssessment(risk);
      setSecurityAlerts(alerts);
    } catch (error) {
      console.error('Failed to load security data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAnomalyDetected = (event: any) => {
    // Update UI when anomaly is detected
    console.log('Anomaly detected:', event);
    loadSecurityData(); // Refresh data
  };

  const handleAlertCreated = (event: any) => {
    // Update UI when new alert is created
    console.log('New security alert:', event);
    loadSecurityData(); // Refresh data
  };

  const getRiskColor = (level: string): string => {
    switch (level) {
      case 'CRITICAL': return '#dc3545';
      case 'HIGH': return '#fd7e14';
      case 'MEDIUM': return '#ffc107';
      case 'LOW': return '#28a745';
      default: return '#6c757d';
    }
  };

  if (loading) {
    return <div className="loading">Loading security data...</div>;
  }

  return (
    <div className="security-dashboard">
      <h2>Security Overview</h2>
      
      {/* Risk Assessment */}
      <div className="risk-assessment">
        <h3>Risk Assessment</h3>
        <div 
          className="risk-score"
          style={{ color: getRiskColor(riskAssessment?.riskLevel) }}
        >
          <span className="score">{riskAssessment?.overallRisk}</span>
          <span className="level">{riskAssessment?.riskLevel}</span>
        </div>
        
        {riskAssessment?.factors && (
          <div className="risk-factors">
            <h4>Risk Factors:</h4>
            <ul>
              {riskAssessment.factors.map((factor: string, index: number) => (
                <li key={index}>{factor}</li>
              ))}
            </ul>
          </div>
        )}
      </div>

      {/* Security Alerts */}
      <div className="security-alerts">
        <h3>Security Alerts</h3>
        {securityAlerts.length === 0 ? (
          <p>No active security alerts</p>
        ) : (
          <div className="alerts-list">
            {securityAlerts.map((alert) => (
              <div 
                key={alert.id} 
                className={`alert alert-${alert.priority.toLowerCase()}`}
              >
                <div className="alert-header">
                  <span className="alert-type">{alert.type}</span>
                  <span className="alert-priority">{alert.priority}</span>
                </div>
                <div className="alert-timestamp">
                  {alert.timestamp.toLocaleString()}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Refresh Button */}
      <button onClick={loadSecurityData} className="refresh-btn">
        Refresh Security Data
      </button>
    </div>
  );
};

export default SecurityDashboard;
```

### Transaction Security Indicators

```typescript
// Component to show transaction security status
interface TransactionSecurityIndicatorProps {
  txHash: string;
  transactionManager: SecureTransactionManager;
}

const TransactionSecurityIndicator: React.FC<TransactionSecurityIndicatorProps> = ({
  txHash,
  transactionManager
}) => {
  const [securityStatus, setSecurityStatus] = useState<{
    verified: boolean;
    riskScore: number;
    proofExists: boolean;
    flagged: boolean;
  } | null>(null);

  useEffect(() => {
    checkTransactionSecurity();
  }, [txHash]);

  const checkTransactionSecurity = async () => {
    try {
      const [verified, details] = await Promise.all([
        transactionManager.verifyTransactionIntegrity(txHash),
        getTransactionDetails(txHash)
      ]);

      setSecurityStatus({
        verified,
        riskScore: details.risk_score,
        proofExists: details.proof_hash !== '0x0',
        flagged: details.flagged
      });
    } catch (error) {
      console.error('Security check failed:', error);
    }
  };

  const getTransactionDetails = async (txHash: string) => {
    // Implementation to get transaction details from contract
    return {
      risk_score: 100,
      proof_hash: '0x123...',
      flagged: false
    };
  };

  if (!securityStatus) {
    return <div className="security-loading">Checking security...</div>;
  }

  return (
    <div className="transaction-security">
      <div className="security-indicators">
        <div className={`indicator ${securityStatus.verified ? 'verified' : 'unverified'}`}>
          <span className="icon">{securityStatus.verified ? '✓' : '⚠'}</span>
          <span className="label">
            {securityStatus.verified ? 'Verified' : 'Unverified'}
          </span>
        </div>

        <div className={`indicator ${securityStatus.proofExists ? 'proven' : 'unproven'}`}>
          <span className="icon">{securityStatus.proofExists ? '🔒' : '🔓'}</span>
          <span className="label">
            {securityStatus.proofExists ? 'Proof Exists' : 'No Proof'}
          </span>
        </div>

        <div className={`indicator ${securityStatus.flagged ? 'flagged' : 'clean'}`}>
          <span className="icon">{securityStatus.flagged ? '🚩' : '✅'}</span>
          <span className="label">
            {securityStatus.flagged ? 'Flagged' : 'Clean'}
          </span>
        </div>
      </div>

      <div className="risk-score">
        <span className="label">Risk Score:</span>
        <span className={`score ${getRiskClass(securityStatus.riskScore)}`}>
          {securityStatus.riskScore}
        </span>
      </div>
    </div>
  );
};

const getRiskClass = (score: number): string => {
  if (score >= 1000) return 'high-risk';
  if (score >= 500) return 'medium-risk';
  return 'low-risk';
};
```

## 🎨 UI/UX Guidelines

### Security Status Colors
- **Green (#28a745)**: Verified, low risk, secure
- **Yellow (#ffc107)**: Medium risk, requires attention
- **Orange (#fd7e14)**: High risk, immediate attention needed
- **Red (#dc3545)**: Critical risk, urgent action required
- **Gray (#6c757d)**: Unknown or pending status

### Security Icons
- **✓**: Verified/Secure
- **⚠**: Warning/Attention needed
- **🔒**: Cryptographically secured
- **🔓**: Not secured
- **🚩**: Flagged/Suspicious
- **✅**: Clean/Safe
- **🛡️**: Protected
- **⚡**: Real-time monitoring active

### User Experience Best Practices

1. **Progressive Disclosure**: Show basic security status first, detailed information on demand
2. **Real-time Updates**: Update security status in real-time without page refresh
3. **Clear Messaging**: Use plain language to explain security concepts
4. **Visual Hierarchy**: Use color and typography to indicate security priority
5. **Actionable Alerts**: Provide clear next steps for security issues

## 🔧 Configuration

### Environment Variables
```bash
# .env file
REACT_APP_STARKNET_NETWORK=testnet
REACT_APP_TRANSACTION_MONITOR_ADDRESS=0x...
REACT_APP_SECURITY_MONITOR_ADDRESS=0x...
REACT_APP_ACCESS_CONTROL_ADDRESS=0x...
REACT_APP_SECURITY_POLLING_INTERVAL=5000
REACT_APP_ENABLE_REAL_TIME_MONITORING=true
```

### Security Configuration
```typescript
interface SecurityConfig {
  pollingInterval: number;
  enableRealTimeMonitoring: boolean;
  riskThresholds: {
    low: number;
    medium: number;
    high: number;
    critical: number;
  };
  alertSettings: {
    showDesktopNotifications: boolean;
    playAlertSounds: boolean;
    emailNotifications: boolean;
  };
}

const defaultSecurityConfig: SecurityConfig = {
  pollingInterval: 5000,
  enableRealTimeMonitoring: true,
  riskThresholds: {
    low: 100,
    medium: 500,
    high: 1000,
    critical: 2000
  },
  alertSettings: {
    showDesktopNotifications: true,
    playAlertSounds: false,
    emailNotifications: true
  }
};
```

## 📱 Mobile Integration

### React Native Components
```typescript
// Mobile-specific security components
import { Alert, Vibration } from 'react-native';

class MobileSecurityService extends SecurityMonitoringService {
  showSecurityAlert(alert: any): void {
    Alert.alert(
      'Security Alert',
      `${alert.type}: ${alert.description}`,
      [
        { text: 'Dismiss', style: 'cancel' },
        { text: 'View Details', onPress: () => this.showAlertDetails(alert) }
      ]
    );

    // Vibrate for critical alerts
    if (alert.priority === 'CRITICAL') {
      Vibration.vibrate([0, 500, 200, 500]);
    }
  }

  private showAlertDetails(alert: any): void {
    // Navigate to alert details screen
  }
}
```

## 🧪 Testing Integration

### Security Feature Testing
```typescript
// Jest tests for security integration
describe('Security Integration', () => {
  let securityService: SecurityMonitoringService;
  let transactionManager: SecureTransactionManager;

  beforeEach(() => {
    // Setup test environment
  });

  test('should record secure transaction', async () => {
    const txData = {
      txHash: '0x123...',
      txType: 'DEPOSIT',
      amount: '1000000000000000000000',
      description: 'Test transaction',
      userAddress: '0x456...'
    };

    const result = await transactionManager.recordSecureTransaction(txData);
    
    expect(result.success).toBe(true);
    expect(result.securityScore).toBeGreaterThanOrEqual(0);
  });

  test('should verify transaction integrity', async () => {
    const txHash = '0x123...';
    const verified = await transactionManager.verifyTransactionIntegrity(txHash);
    
    expect(typeof verified).toBe('boolean');
  });

  test('should get user risk assessment', async () => {
    const userAddress = '0x456...';
    const risk = await securityService.getUserRiskAssessment(userAddress);
    
    expect(risk).toHaveProperty('overallRisk');
    expect(risk).toHaveProperty('riskLevel');
    expect(risk).toHaveProperty('factors');
  });
});
```

---

**Integration Support**: security-integration@starkpulse.com
**Documentation Updates**: Weekly updates with new features
**Community Support**: Discord #frontend-integration
**Bug Reports**: GitHub Issues with 'frontend' label

**Last Updated**: $(date)
**Version**: 1.0
**Owner**: StarkPulse Frontend Team
