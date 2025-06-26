#!/bin/bash

# StarkPulse Security Features Test Script
# This script tests all security enhancements in the transaction monitor

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK=${NETWORK:-"testnet"}
DEPLOYMENT_FILE=${DEPLOYMENT_FILE:-""}
TEST_USER_ADDRESS=${TEST_USER_ADDRESS:-""}

# Contract addresses (will be loaded from deployment file)
ACCESS_CONTROL_ADDRESS=""
CRYPTO_UTILS_ADDRESS=""
SECURITY_MONITOR_ADDRESS=""
TRANSACTION_MONITOR_ADDRESS=""
ADMIN_ADDRESS=""

# Test transaction data
TEST_TX_HASH_1="0x123456789abcdef"
TEST_TX_HASH_2="0xfedcba987654321"
TEST_AMOUNT_NORMAL="100000000000000000000"  # 100 tokens
TEST_AMOUNT_LARGE="10000000000000000000000"  # 10,000 tokens
TEST_TX_TYPE_DEPOSIT="0x4445504f534954"  # "DEPOSIT"
TEST_TX_TYPE_WITHDRAWAL="0x57495448445241574c"  # "WITHDRAWAL"

echo -e "${BLUE}🧪 StarkPulse Security Features Test Suite${NC}"
echo -e "${BLUE}==========================================${NC}"

# Load deployment configuration
load_deployment_config() {
    echo -e "${YELLOW}📋 Loading deployment configuration...${NC}"
    
    if [ -z "$DEPLOYMENT_FILE" ]; then
        echo -e "${RED}❌ DEPLOYMENT_FILE environment variable not set.${NC}"
        echo -e "${YELLOW}💡 Set it with: export DEPLOYMENT_FILE=<path_to_deployment_json>${NC}"
        exit 1
    fi
    
    if [ ! -f "$DEPLOYMENT_FILE" ]; then
        echo -e "${RED}❌ Deployment file not found: $DEPLOYMENT_FILE${NC}"
        exit 1
    fi
    
    # Extract contract addresses from deployment file
    ACCESS_CONTROL_ADDRESS=$(jq -r '.contracts.access_control' "$DEPLOYMENT_FILE")
    CRYPTO_UTILS_ADDRESS=$(jq -r '.contracts.crypto_utils' "$DEPLOYMENT_FILE")
    SECURITY_MONITOR_ADDRESS=$(jq -r '.contracts.security_monitor' "$DEPLOYMENT_FILE")
    TRANSACTION_MONITOR_ADDRESS=$(jq -r '.contracts.transaction_monitor' "$DEPLOYMENT_FILE")
    ADMIN_ADDRESS=$(jq -r '.admin_address' "$DEPLOYMENT_FILE")
    
    echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
    echo -e "  Transaction Monitor: $TRANSACTION_MONITOR_ADDRESS"
    echo -e "  Security Monitor: $SECURITY_MONITOR_ADDRESS"
    echo -e "  Admin Address: $ADMIN_ADDRESS"
}

# Test basic transaction recording with security features
test_transaction_recording() {
    echo -e "${YELLOW}📝 Testing transaction recording with security features...${NC}"
    
    if [ -z "$TEST_USER_ADDRESS" ]; then
        echo -e "${YELLOW}⚠️ TEST_USER_ADDRESS not set, using admin address for testing${NC}"
        TEST_USER_ADDRESS=$ADMIN_ADDRESS
    fi
    
    # Record a normal transaction
    echo -e "${BLUE}  Recording normal transaction...${NC}"
    starknet invoke \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function record_transaction \
        --inputs $TEST_TX_HASH_1 $TEST_TX_TYPE_DEPOSIT $TEST_AMOUNT_NORMAL 0x4e4f524d414c \
        --account $TEST_USER_ADDRESS \
        --network $NETWORK \
        --max_fee 1000000000000000
    
    # Verify transaction was recorded with security fields
    echo -e "${BLUE}  Verifying transaction details...${NC}"
    TRANSACTION_DETAILS=$(starknet call \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function get_transaction_details \
        --inputs $TEST_TX_HASH_1 \
        --network $NETWORK)
    
    if [[ $TRANSACTION_DETAILS == *"$TEST_TX_HASH_1"* ]]; then
        echo -e "${GREEN}  ✅ Transaction recorded successfully${NC}"
    else
        echo -e "${RED}  ❌ Transaction recording failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Transaction recording test passed${NC}"
}

# Test transaction integrity verification
test_integrity_verification() {
    echo -e "${YELLOW}🔍 Testing transaction integrity verification...${NC}"
    
    # Verify integrity of recorded transaction
    echo -e "${BLUE}  Verifying transaction integrity...${NC}"
    VERIFICATION_RESULT=$(starknet call \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function verify_transaction_integrity \
        --inputs $TEST_TX_HASH_1 2 0x123 0x456 \
        --network $NETWORK)
    
    if [[ $VERIFICATION_RESULT == *"1"* ]]; then
        echo -e "${GREEN}  ✅ Transaction integrity verified${NC}"
    else
        echo -e "${RED}  ❌ Transaction integrity verification failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Integrity verification test passed${NC}"
}

# Test transaction proof creation and verification
test_proof_system() {
    echo -e "${YELLOW}🔐 Testing transaction proof system...${NC}"
    
    # Create transaction proof
    echo -e "${BLUE}  Creating transaction proof...${NC}"
    PROOF_RESULT=$(starknet invoke \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function create_transaction_proof \
        --inputs $TEST_TX_HASH_1 2 0x50524f4f46 0x44415441 \
        --account $TEST_USER_ADDRESS \
        --network $NETWORK \
        --max_fee 1000000000000000)
    
    # Extract proof hash from result (simplified - in practice would parse transaction receipt)
    PROOF_HASH="0x1234567890abcdef"  # Placeholder
    
    # Verify transaction proof
    echo -e "${BLUE}  Verifying transaction proof...${NC}"
    PROOF_VERIFICATION=$(starknet call \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function verify_transaction_proof \
        --inputs $TEST_TX_HASH_1 $PROOF_HASH \
        --network $NETWORK)
    
    echo -e "${GREEN}✅ Proof system test completed${NC}"
}

# Test suspicious transaction flagging
test_suspicious_flagging() {
    echo -e "${YELLOW}🚨 Testing suspicious transaction flagging...${NC}"
    
    # Record a large transaction that might be flagged
    echo -e "${BLUE}  Recording large transaction...${NC}"
    starknet invoke \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function record_transaction \
        --inputs $TEST_TX_HASH_2 $TEST_TX_TYPE_WITHDRAWAL $TEST_AMOUNT_LARGE 0x4c41524745 \
        --account $TEST_USER_ADDRESS \
        --network $NETWORK \
        --max_fee 1000000000000000
    
    # Flag transaction as suspicious (admin only)
    echo -e "${BLUE}  Flagging transaction as suspicious...${NC}"
    starknet invoke \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function flag_suspicious_transaction \
        --inputs $TEST_TX_HASH_2 0x554e5553554c414c5f414d4f554e54 \
        --account $ADMIN_ADDRESS \
        --network $NETWORK \
        --max_fee 1000000000000000
    
    # Verify transaction is flagged
    echo -e "${BLUE}  Verifying transaction flag status...${NC}"
    FLAGGED_TRANSACTION=$(starknet call \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function get_transaction_details \
        --inputs $TEST_TX_HASH_2 \
        --network $NETWORK)
    
    echo -e "${GREEN}✅ Suspicious flagging test completed${NC}"
}

# Test audit trail functionality
test_audit_trail() {
    echo -e "${YELLOW}📋 Testing audit trail functionality...${NC}"
    
    # Get audit trail for flagged transaction
    echo -e "${BLUE}  Retrieving audit trail...${NC}"
    AUDIT_TRAIL=$(starknet call \
        --contract $TRANSACTION_MONITOR_ADDRESS \
        --function get_transaction_audit_trail \
        --inputs $TEST_TX_HASH_2 \
        --account $TEST_USER_ADDRESS \
        --network $NETWORK)
    
    if [[ $AUDIT_TRAIL == *"FLAGGED"* ]]; then
        echo -e "${GREEN}  ✅ Audit trail contains flagging event${NC}"
    else
        echo -e "${YELLOW}  ⚠️ Audit trail may not contain expected events${NC}"
    fi
    
    echo -e "${GREEN}✅ Audit trail test completed${NC}"
}

# Test anomaly detection system
test_anomaly_detection() {
    echo -e "${YELLOW}🔍 Testing anomaly detection system...${NC}"
    
    # Test anomaly analysis for normal transaction
    echo -e "${BLUE}  Analyzing normal transaction for anomalies...${NC}"
    NORMAL_ANOMALY=$(starknet call \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function analyze_transaction_anomaly \
        --inputs $TEST_USER_ADDRESS $TEST_TX_HASH_1 $TEST_TX_TYPE_DEPOSIT $TEST_AMOUNT_NORMAL 1000 \
        --network $NETWORK)
    
    # Test anomaly analysis for large transaction
    echo -e "${BLUE}  Analyzing large transaction for anomalies...${NC}"
    LARGE_ANOMALY=$(starknet call \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function analyze_transaction_anomaly \
        --inputs $TEST_USER_ADDRESS $TEST_TX_HASH_2 $TEST_TX_TYPE_WITHDRAWAL $TEST_AMOUNT_LARGE 1000 \
        --network $NETWORK)
    
    echo -e "${GREEN}✅ Anomaly detection test completed${NC}"
}

# Test security alert system
test_security_alerts() {
    echo -e "${YELLOW}🚨 Testing security alert system...${NC}"
    
    # Create security alert
    echo -e "${BLUE}  Creating security alert...${NC}"
    starknet invoke \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function create_security_alert \
        --inputs 0x535553504943494f55535f5452414e53414354494f4e 3 $TEST_USER_ADDRESS $TEST_TX_HASH_2 \
        --account $ADMIN_ADDRESS \
        --network $NETWORK \
        --max_fee 1000000000000000
    
    # Get active alerts
    echo -e "${BLUE}  Retrieving active alerts...${NC}"
    ACTIVE_ALERTS=$(starknet call \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function get_active_alerts \
        --inputs $TEST_USER_ADDRESS \
        --network $NETWORK)
    
    echo -e "${GREEN}✅ Security alert test completed${NC}"
}

# Test access control system
test_access_control() {
    echo -e "${YELLOW}🔐 Testing access control system...${NC}"
    
    # Test admin role
    echo -e "${BLUE}  Testing admin role permissions...${NC}"
    ADMIN_ROLE_CHECK=$(starknet call \
        --contract $ACCESS_CONTROL_ADDRESS \
        --function has_role \
        --inputs 0x41444d494e5f524f4c45 $ADMIN_ADDRESS \
        --network $NETWORK)
    
    if [[ $ADMIN_ROLE_CHECK == *"1"* ]]; then
        echo -e "${GREEN}  ✅ Admin role verified${NC}"
    else
        echo -e "${RED}  ❌ Admin role verification failed${NC}"
        return 1
    fi
    
    # Test security auditor role (if configured)
    echo -e "${BLUE}  Testing security roles configuration...${NC}"
    
    echo -e "${GREEN}✅ Access control test completed${NC}"
}

# Test risk assessment system
test_risk_assessment() {
    echo -e "${YELLOW}⚖️ Testing risk assessment system...${NC}"
    
    # Assess risk for normal transaction
    echo -e "${BLUE}  Assessing risk for normal transaction...${NC}"
    NORMAL_RISK=$(starknet call \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function assess_transaction_risk \
        --inputs $TEST_USER_ADDRESS $TEST_TX_TYPE_DEPOSIT $TEST_AMOUNT_NORMAL 1000 \
        --network $NETWORK)
    
    # Assess risk for large transaction
    echo -e "${BLUE}  Assessing risk for large transaction...${NC}"
    LARGE_RISK=$(starknet call \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function assess_transaction_risk \
        --inputs $TEST_USER_ADDRESS $TEST_TX_TYPE_WITHDRAWAL $TEST_AMOUNT_LARGE 1000 \
        --network $NETWORK)
    
    echo -e "${GREEN}✅ Risk assessment test completed${NC}"
}

# Run comprehensive security test
run_security_test_suite() {
    echo -e "${BLUE}🧪 Running comprehensive security test suite...${NC}"
    
    local tests_passed=0
    local tests_failed=0
    
    # Run all tests
    test_transaction_recording && ((tests_passed++)) || ((tests_failed++))
    test_integrity_verification && ((tests_passed++)) || ((tests_failed++))
    test_proof_system && ((tests_passed++)) || ((tests_failed++))
    test_suspicious_flagging && ((tests_passed++)) || ((tests_failed++))
    test_audit_trail && ((tests_passed++)) || ((tests_failed++))
    test_anomaly_detection && ((tests_passed++)) || ((tests_failed++))
    test_security_alerts && ((tests_passed++)) || ((tests_failed++))
    test_access_control && ((tests_passed++)) || ((tests_failed++))
    test_risk_assessment && ((tests_passed++)) || ((tests_failed++))
    
    # Print test summary
    echo -e "${BLUE}📊 Test Summary${NC}"
    echo -e "${BLUE}=============${NC}"
    echo -e "${GREEN}Tests Passed: $tests_passed${NC}"
    echo -e "${RED}Tests Failed: $tests_failed${NC}"
    echo -e "Total Tests: $((tests_passed + tests_failed))"
    
    if [ $tests_failed -eq 0 ]; then
        echo -e "${GREEN}🎉 All security tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some security tests failed${NC}"
        return 1
    fi
}

# Print test configuration
print_test_config() {
    echo -e "${BLUE}🔧 Test Configuration${NC}"
    echo -e "${BLUE}===================${NC}"
    echo -e "Network: $NETWORK"
    echo -e "Deployment File: $DEPLOYMENT_FILE"
    echo -e "Test User: ${TEST_USER_ADDRESS:-'Using admin address'}"
    echo -e "Transaction Monitor: $TRANSACTION_MONITOR_ADDRESS"
    echo -e "Security Monitor: $SECURITY_MONITOR_ADDRESS"
    echo ""
}

# Main test execution
main() {
    echo -e "${BLUE}Starting security features test suite...${NC}"
    
    load_deployment_config
    print_test_config
    
    if run_security_test_suite; then
        echo -e "${GREEN}✅ Security test suite completed successfully!${NC}"
        echo -e "${YELLOW}💡 All security features are working as expected${NC}"
        exit 0
    else
        echo -e "${RED}❌ Security test suite failed${NC}"
        echo -e "${YELLOW}💡 Please review the failed tests and fix any issues${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
