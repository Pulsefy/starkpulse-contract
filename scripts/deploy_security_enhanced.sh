#!/bin/bash

# StarkPulse Security Enhanced Deployment Script
# This script deploys the enhanced transaction monitor with security features

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NETWORK=${NETWORK:-"testnet"}
ADMIN_ADDRESS=${ADMIN_ADDRESS:-""}
SECURITY_AUDITOR_ADDRESS=${SECURITY_AUDITOR_ADDRESS:-""}
ANOMALY_DETECTOR_ADDRESS=${ANOMALY_DETECTOR_ADDRESS:-""}
CRYPTO_VERIFIER_ADDRESS=${CRYPTO_VERIFIER_ADDRESS:-""}

# Contract names
ACCESS_CONTROL_CONTRACT="AccessControl"
CRYPTO_UTILS_CONTRACT="CryptoUtils"
SECURITY_MONITOR_CONTRACT="SecurityMonitor"
TRANSACTION_MONITOR_CONTRACT="TransactionMonitor"

# Deployment addresses (will be populated during deployment)
ACCESS_CONTROL_ADDRESS=""
CRYPTO_UTILS_ADDRESS=""
SECURITY_MONITOR_ADDRESS=""
TRANSACTION_MONITOR_ADDRESS=""

echo -e "${BLUE}🔒 StarkPulse Security Enhanced Deployment${NC}"
echo -e "${BLUE}=========================================${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
    
    if ! command -v starknet &> /dev/null; then
        echo -e "${RED}❌ StarkNet CLI not found. Please install it first.${NC}"
        exit 1
    fi
    
    if ! command -v scarb &> /dev/null; then
        echo -e "${RED}❌ Scarb not found. Please install it first.${NC}"
        exit 1
    fi
    
    if [ -z "$ADMIN_ADDRESS" ]; then
        echo -e "${RED}❌ ADMIN_ADDRESS environment variable not set.${NC}"
        echo -e "${YELLOW}💡 Set it with: export ADMIN_ADDRESS=<your_admin_address>${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Build contracts
build_contracts() {
    echo -e "${YELLOW}🔨 Building contracts...${NC}"
    
    cd contracts
    scarb build
    cd ..
    
    echo -e "${GREEN}✅ Contracts built successfully${NC}"
}

# Deploy Access Control contract
deploy_access_control() {
    echo -e "${YELLOW}🚀 Deploying Access Control contract...${NC}"
    
    ACCESS_CONTROL_ADDRESS=$(starknet deploy \
        --contract target/dev/starkpulse_contract_AccessControl.sierra.json \
        --inputs $ADMIN_ADDRESS \
        --network $NETWORK \
        --max_fee 1000000000000000 \
        | grep "Contract address:" | awk '{print $3}')
    
    if [ -z "$ACCESS_CONTROL_ADDRESS" ]; then
        echo -e "${RED}❌ Failed to deploy Access Control contract${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Access Control deployed at: $ACCESS_CONTROL_ADDRESS${NC}"
}

# Deploy Crypto Utils contract
deploy_crypto_utils() {
    echo -e "${YELLOW}🔐 Deploying Crypto Utils contract...${NC}"
    
    CRYPTO_UTILS_ADDRESS=$(starknet deploy \
        --contract target/dev/starkpulse_contract_CryptoUtils.sierra.json \
        --network $NETWORK \
        --max_fee 1000000000000000 \
        | grep "Contract address:" | awk '{print $3}')
    
    if [ -z "$CRYPTO_UTILS_ADDRESS" ]; then
        echo -e "${RED}❌ Failed to deploy Crypto Utils contract${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Crypto Utils deployed at: $CRYPTO_UTILS_ADDRESS${NC}"
}

# Deploy Security Monitor contract
deploy_security_monitor() {
    echo -e "${YELLOW}🛡️ Deploying Security Monitor contract...${NC}"
    
    SECURITY_MONITOR_ADDRESS=$(starknet deploy \
        --contract target/dev/starkpulse_contract_SecurityMonitor.sierra.json \
        --inputs $ADMIN_ADDRESS \
        --network $NETWORK \
        --max_fee 1000000000000000 \
        | grep "Contract address:" | awk '{print $3}')
    
    if [ -z "$SECURITY_MONITOR_ADDRESS" ]; then
        echo -e "${RED}❌ Failed to deploy Security Monitor contract${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Security Monitor deployed at: $SECURITY_MONITOR_ADDRESS${NC}"
}

# Deploy Transaction Monitor contract
deploy_transaction_monitor() {
    echo -e "${YELLOW}📊 Deploying Enhanced Transaction Monitor contract...${NC}"
    
    TRANSACTION_MONITOR_ADDRESS=$(starknet deploy \
        --contract target/dev/starkpulse_contract_TransactionMonitor.sierra.json \
        --inputs $ADMIN_ADDRESS $CRYPTO_UTILS_ADDRESS $SECURITY_MONITOR_ADDRESS \
        --network $NETWORK \
        --max_fee 1000000000000000 \
        | grep "Contract address:" | awk '{print $3}')
    
    if [ -z "$TRANSACTION_MONITOR_ADDRESS" ]; then
        echo -e "${RED}❌ Failed to deploy Transaction Monitor contract${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Transaction Monitor deployed at: $TRANSACTION_MONITOR_ADDRESS${NC}"
}

# Configure security roles
configure_security_roles() {
    echo -e "${YELLOW}👥 Configuring security roles...${NC}"
    
    # Grant Security Auditor role
    if [ ! -z "$SECURITY_AUDITOR_ADDRESS" ]; then
        echo -e "${BLUE}🔍 Granting Security Auditor role to $SECURITY_AUDITOR_ADDRESS${NC}"
        starknet invoke \
            --contract $ACCESS_CONTROL_ADDRESS \
            --function grant_role \
            --inputs 0x534543555249545f41554449544f525f524f4c45 $SECURITY_AUDITOR_ADDRESS \
            --network $NETWORK \
            --max_fee 1000000000000000
    fi
    
    # Grant Anomaly Detector role
    if [ ! -z "$ANOMALY_DETECTOR_ADDRESS" ]; then
        echo -e "${BLUE}🚨 Granting Anomaly Detector role to $ANOMALY_DETECTOR_ADDRESS${NC}"
        starknet invoke \
            --contract $ACCESS_CONTROL_ADDRESS \
            --function grant_role \
            --inputs 0x414e4f4d414c595f444554454354525f524f4c45 $ANOMALY_DETECTOR_ADDRESS \
            --network $NETWORK \
            --max_fee 1000000000000000
    fi
    
    # Grant Crypto Verifier role
    if [ ! -z "$CRYPTO_VERIFIER_ADDRESS" ]; then
        echo -e "${BLUE}🔐 Granting Crypto Verifier role to $CRYPTO_VERIFIER_ADDRESS${NC}"
        starknet invoke \
            --contract $ACCESS_CONTROL_ADDRESS \
            --function grant_role \
            --inputs 0x43525950544f5f5645524946494552524f4c45 $CRYPTO_VERIFIER_ADDRESS \
            --network $NETWORK \
            --max_fee 1000000000000000
    fi
    
    echo -e "${GREEN}✅ Security roles configured${NC}"
}

# Set anomaly detection thresholds
configure_thresholds() {
    echo -e "${YELLOW}⚙️ Configuring anomaly detection thresholds...${NC}"
    
    # Set LOW threshold
    starknet invoke \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function set_anomaly_threshold \
        --inputs 0x4c4f57 100 \
        --network $NETWORK \
        --max_fee 1000000000000000
    
    # Set MEDIUM threshold
    starknet invoke \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function set_anomaly_threshold \
        --inputs 0x4d454449554d 500 \
        --network $NETWORK \
        --max_fee 1000000000000000
    
    # Set HIGH threshold
    starknet invoke \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function set_anomaly_threshold \
        --inputs 0x48494748 1000 \
        --network $NETWORK \
        --max_fee 1000000000000000
    
    # Set CRITICAL threshold
    starknet invoke \
        --contract $SECURITY_MONITOR_ADDRESS \
        --function set_anomaly_threshold \
        --inputs 0x435249544943414c 2000 \
        --network $NETWORK \
        --max_fee 1000000000000000
    
    echo -e "${GREEN}✅ Anomaly detection thresholds configured${NC}"
}

# Save deployment information
save_deployment_info() {
    echo -e "${YELLOW}💾 Saving deployment information...${NC}"
    
    DEPLOYMENT_FILE="deployments/security_enhanced_${NETWORK}_$(date +%Y%m%d_%H%M%S).json"
    mkdir -p deployments
    
    cat > $DEPLOYMENT_FILE << EOF
{
  "network": "$NETWORK",
  "deployment_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "admin_address": "$ADMIN_ADDRESS",
  "contracts": {
    "access_control": "$ACCESS_CONTROL_ADDRESS",
    "crypto_utils": "$CRYPTO_UTILS_ADDRESS",
    "security_monitor": "$SECURITY_MONITOR_ADDRESS",
    "transaction_monitor": "$TRANSACTION_MONITOR_ADDRESS"
  },
  "security_roles": {
    "security_auditor": "$SECURITY_AUDITOR_ADDRESS",
    "anomaly_detector": "$ANOMALY_DETECTOR_ADDRESS",
    "crypto_verifier": "$CRYPTO_VERIFIER_ADDRESS"
  },
  "configuration": {
    "anomaly_thresholds": {
      "low": 100,
      "medium": 500,
      "high": 1000,
      "critical": 2000
    }
  }
}
EOF
    
    echo -e "${GREEN}✅ Deployment info saved to: $DEPLOYMENT_FILE${NC}"
}

# Print deployment summary
print_summary() {
    echo -e "${BLUE}📋 Deployment Summary${NC}"
    echo -e "${BLUE}===================${NC}"
    echo -e "${GREEN}Network:${NC} $NETWORK"
    echo -e "${GREEN}Admin Address:${NC} $ADMIN_ADDRESS"
    echo ""
    echo -e "${GREEN}Deployed Contracts:${NC}"
    echo -e "  🔐 Access Control:      $ACCESS_CONTROL_ADDRESS"
    echo -e "  🔒 Crypto Utils:        $CRYPTO_UTILS_ADDRESS"
    echo -e "  🛡️  Security Monitor:    $SECURITY_MONITOR_ADDRESS"
    echo -e "  📊 Transaction Monitor: $TRANSACTION_MONITOR_ADDRESS"
    echo ""
    echo -e "${GREEN}Security Roles:${NC}"
    echo -e "  🔍 Security Auditor:    ${SECURITY_AUDITOR_ADDRESS:-'Not configured'}"
    echo -e "  🚨 Anomaly Detector:    ${ANOMALY_DETECTOR_ADDRESS:-'Not configured'}"
    echo -e "  🔐 Crypto Verifier:     ${CRYPTO_VERIFIER_ADDRESS:-'Not configured'}"
    echo ""
    echo -e "${GREEN}✅ Security enhanced deployment completed successfully!${NC}"
    echo -e "${YELLOW}💡 Next steps:${NC}"
    echo -e "  1. Test the deployment with the provided test scripts"
    echo -e "  2. Configure monitoring and alerting systems"
    echo -e "  3. Set up frontend integration"
    echo -e "  4. Conduct security audit"
}

# Main deployment flow
main() {
    echo -e "${BLUE}Starting security enhanced deployment...${NC}"
    
    check_prerequisites
    build_contracts
    deploy_access_control
    deploy_crypto_utils
    deploy_security_monitor
    deploy_transaction_monitor
    configure_security_roles
    configure_thresholds
    save_deployment_info
    print_summary
}

# Run main function
main "$@"
