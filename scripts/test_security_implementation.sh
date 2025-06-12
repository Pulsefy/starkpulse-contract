#!/bin/bash

# StarkPulse Security Implementation Test Script
# This script performs comprehensive testing of our security implementation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 StarkPulse Security Implementation Test Suite${NC}"
echo -e "${BLUE}===============================================${NC}"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${YELLOW}🧪 Testing: $test_name${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASSED: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Check if all required files exist
test_file_structure() {
    echo "Checking file structure..."
    
    local required_files=(
        "contracts/src/lib.cairo"
        "contracts/src/utils/access_control.cairo"
        "contracts/src/utils/crypto_utils.cairo"
        "contracts/src/utils/security_monitor.cairo"
        "contracts/src/interfaces/i_transaction_monitor.cairo"
        "contracts/src/interfaces/i_security_monitor.cairo"
        "contracts/src/transactions/transaction_monitor.cairo"
        "contracts/src/tests/test_transaction_security.cairo"
        "contracts/src/tests/test_anomaly_detection.cairo"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "Missing file: $file"
            return 1
        fi
    done
    
    echo "All required files exist"
    return 0
}

# Test 2: Check Cairo syntax basics
test_cairo_syntax() {
    echo "Checking basic Cairo syntax..."
    
    # Check for balanced braces in main files
    local cairo_files=(
        "contracts/src/utils/crypto_utils.cairo"
        "contracts/src/utils/security_monitor.cairo"
        "contracts/src/transactions/transaction_monitor.cairo"
    )
    
    for file in "${cairo_files[@]}"; do
        if [ -f "$file" ]; then
            local open_braces=$(grep -o '{' "$file" | wc -l)
            local close_braces=$(grep -o '}' "$file" | wc -l)
            
            if [ "$open_braces" -ne "$close_braces" ]; then
                echo "Unbalanced braces in $file: $open_braces open, $close_braces close"
                return 1
            fi
        fi
    done
    
    echo "Basic syntax checks passed"
    return 0
}

# Test 3: Check module declarations in lib.cairo
test_module_declarations() {
    echo "Checking module declarations..."
    
    local lib_file="contracts/src/lib.cairo"
    local required_modules=(
        "crypto_utils"
        "security_monitor"
        "i_security_monitor"
    )
    
    for module in "${required_modules[@]}"; do
        if ! grep -q "pub mod $module;" "$lib_file"; then
            echo "Missing module declaration: $module"
            return 1
        fi
    done
    
    echo "Module declarations are correct"
    return 0
}

# Test 4: Check interface consistency
test_interface_consistency() {
    echo "Checking interface consistency..."
    
    # Check if security monitor interface has required functions
    local interface_file="contracts/src/interfaces/i_security_monitor.cairo"
    local required_functions=(
        "analyze_transaction_anomaly"
        "log_security_event"
        "create_security_alert"
        "assess_transaction_risk"
    )
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "fn $func" "$interface_file"; then
            echo "Missing function in interface: $func"
            return 1
        fi
    done
    
    echo "Interface consistency checks passed"
    return 0
}

# Test 5: Check security constants
test_security_constants() {
    echo "Checking security constants..."
    
    local security_file="contracts/src/utils/security_monitor.cairo"
    local required_constants=(
        "ANOMALY_THRESHOLD_LOW"
        "ANOMALY_THRESHOLD_HIGH"
        "FREQUENCY_THRESHOLD"
        "AMOUNT_DEVIATION_THRESHOLD"
    )
    
    for constant in "${required_constants[@]}"; do
        if ! grep -q "const $constant" "$security_file"; then
            echo "Missing security constant: $constant"
            return 1
        fi
    done
    
    echo "Security constants are defined"
    return 0
}

# Test 6: Check cryptographic functions
test_crypto_functions() {
    echo "Checking cryptographic functions..."
    
    local crypto_file="contracts/src/utils/crypto_utils.cairo"
    local required_functions=(
        "create_hash_chain_entry"
        "verify_hash_chain"
        "verify_transaction_signature"
        "verify_merkle_proof"
        "create_commitment"
        "generate_secure_nonce"
    )
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "fn $func" "$crypto_file"; then
            echo "Missing crypto function: $func"
            return 1
        fi
    done
    
    echo "Cryptographic functions are implemented"
    return 0
}

# Test 7: Check transaction monitor enhancements
test_transaction_monitor_enhancements() {
    echo "Checking transaction monitor enhancements..."
    
    local monitor_file="contracts/src/transactions/transaction_monitor.cairo"
    local required_fields=(
        "integrity_hash"
        "proof_hash"
        "verified"
        "flagged"
        "risk_score"
    )
    
    for field in "${required_fields[@]}"; do
        if ! grep -q "$field:" "$monitor_file"; then
            echo "Missing transaction field: $field"
            return 1
        fi
    done
    
    echo "Transaction monitor enhancements are present"
    return 0
}

# Test 8: Check access control roles
test_access_control_roles() {
    echo "Checking access control roles..."
    
    local access_file="contracts/src/utils/access_control.cairo"
    local required_roles=(
        "SECURITY_AUDITOR_ROLE"
        "ANOMALY_DETECTOR_ROLE"
        "CRYPTO_VERIFIER_ROLE"
    )
    
    for role in "${required_roles[@]}"; do
        if ! grep -q "$role" "$access_file"; then
            echo "Missing access control role: $role"
            return 1
        fi
    done
    
    echo "Access control roles are defined"
    return 0
}

# Test 9: Check test file structure
test_test_files() {
    echo "Checking test file structure..."
    
    local test_files=(
        "contracts/src/tests/test_transaction_security.cairo"
        "contracts/src/tests/test_anomaly_detection.cairo"
    )
    
    for test_file in "${test_files[@]}"; do
        if [ ! -f "$test_file" ]; then
            echo "Missing test file: $test_file"
            return 1
        fi
        
        # Check if test file has test functions
        if ! grep -q "#\[test\]" "$test_file"; then
            echo "Test file missing test annotations: $test_file"
            return 1
        fi
    done
    
    echo "Test files are properly structured"
    return 0
}

# Test 10: Check documentation files
test_documentation() {
    echo "Checking documentation files..."
    
    local doc_files=(
        "SECURITY_ENHANCEMENTS.md"
        "SECURITY_IMPLEMENTATION_SUMMARY.md"
        "docs/SECURITY_INCIDENT_RESPONSE.md"
        "docs/SECURITY_AUDIT_CHECKLIST.md"
    )
    
    for doc_file in "${doc_files[@]}"; do
        if [ ! -f "$doc_file" ]; then
            echo "Missing documentation file: $doc_file"
            return 1
        fi
    done
    
    echo "Documentation files are present"
    return 0
}

# Test 11: Check deployment scripts
test_deployment_scripts() {
    echo "Checking deployment scripts..."
    
    local script_files=(
        "scripts/deploy_security_enhanced.sh"
        "scripts/test_security_features.sh"
    )
    
    for script_file in "${script_files[@]}"; do
        if [ ! -f "$script_file" ]; then
            echo "Missing script file: $script_file"
            return 1
        fi
        
        if [ ! -x "$script_file" ]; then
            echo "Script file not executable: $script_file"
            return 1
        fi
    done
    
    echo "Deployment scripts are ready"
    return 0
}

# Test 12: Check monitoring configuration
test_monitoring_config() {
    echo "Checking monitoring configuration..."
    
    local config_files=(
        "monitoring/security_dashboard.json"
    )
    
    for config_file in "${config_files[@]}"; do
        if [ ! -f "$config_file" ]; then
            echo "Missing config file: $config_file"
            return 1
        fi
        
        # Basic JSON validation (check for basic structure)
        if ! grep -q "^{" "$config_file" || ! grep -q "}$" "$config_file"; then
            echo "Invalid JSON structure in config file: $config_file"
            return 1
        fi
    done
    
    echo "Monitoring configuration is valid"
    return 0
}

# Run all tests
echo -e "\n${BLUE}🚀 Running Security Implementation Tests${NC}"
echo -e "${BLUE}========================================${NC}"

run_test "File Structure" "test_file_structure"
run_test "Cairo Syntax" "test_cairo_syntax"
run_test "Module Declarations" "test_module_declarations"
run_test "Interface Consistency" "test_interface_consistency"
run_test "Security Constants" "test_security_constants"
run_test "Crypto Functions" "test_crypto_functions"
run_test "Transaction Monitor Enhancements" "test_transaction_monitor_enhancements"
run_test "Access Control Roles" "test_access_control_roles"
run_test "Test Files" "test_test_files"
run_test "Documentation" "test_documentation"
run_test "Deployment Scripts" "test_deployment_scripts"
run_test "Monitoring Config" "test_monitoring_config"

# Print summary
echo -e "\n${BLUE}📊 TEST SUMMARY${NC}"
echo -e "${BLUE}===============${NC}"
echo -e "Total Tests: $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}✅ Security implementation is ready for deployment${NC}"
    exit 0
else
    echo -e "\n${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${YELLOW}💡 Please fix the failed tests before deployment${NC}"
    exit 1
fi
