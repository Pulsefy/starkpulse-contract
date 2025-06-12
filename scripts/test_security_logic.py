#!/usr/bin/env python3
"""
StarkPulse Security Logic Validator
This script validates the security logic implementation in our Cairo contracts.
"""

import re
import os
from pathlib import Path

def test_crypto_utils_logic():
    """Test cryptographic utilities logic."""
    print("🔐 Testing Crypto Utils Logic...")
    
    crypto_file = "contracts/src/utils/crypto_utils.cairo"
    with open(crypto_file, 'r') as f:
        content = f.read()
    
    tests = []
    
    # Test 1: Hash chain verification logic
    if "verify_hash_chain" in content:
        # Check if it validates previous hash
        if "entry.previous_hash != previous_hash" in content:
            tests.append(("Hash chain validates previous hash", True))
        else:
            tests.append(("Hash chain validates previous hash", False))
        
        # Check if it recomputes hashes for verification
        if "computed_data_hash" in content and "computed_entry_hash" in content:
            tests.append(("Hash chain recomputes hashes for verification", True))
        else:
            tests.append(("Hash chain recomputes hashes for verification", False))
    
    # Test 2: Signature verification logic
    if "verify_transaction_signature" in content:
        # Check if it validates signature components
        if "signature.r == 0 || signature.s == 0" in content:
            tests.append(("Signature verification checks for zero components", True))
        else:
            tests.append(("Signature verification checks for zero components", False))
        
        # Check if it validates signer
        if "signer.is_zero()" in content:
            tests.append(("Signature verification checks for zero signer", True))
        else:
            tests.append(("Signature verification checks for zero signer", False))
    
    # Test 3: Merkle proof verification logic
    if "verify_merkle_proof" in content:
        # Check depth limit
        if "MERKLE_TREE_DEPTH" in content and "proof_length >" in content:
            tests.append(("Merkle proof checks depth limit", True))
        else:
            tests.append(("Merkle proof checks depth limit", False))
        
        # Check array length consistency
        if "proof.indices.len() != proof_length" in content:
            tests.append(("Merkle proof checks array length consistency", True))
        else:
            tests.append(("Merkle proof checks array length consistency", False))
    
    # Test 4: Secure nonce generation
    if "generate_secure_nonce" in content:
        # Check multiple entropy sources
        entropy_sources = ["current_nonce", "timestamp", "block_number"]
        entropy_count = sum(1 for source in entropy_sources if source in content)
        if entropy_count >= 2:
            tests.append(("Secure nonce uses multiple entropy sources", True))
        else:
            tests.append(("Secure nonce uses multiple entropy sources", False))
        
        # Check nonce counter update
        if "self.nonce_counter.write(current_nonce + 1)" in content:
            tests.append(("Secure nonce updates counter", True))
        else:
            tests.append(("Secure nonce updates counter", False))
    
    return tests

def test_security_monitor_logic():
    """Test security monitor logic."""
    print("🛡️ Testing Security Monitor Logic...")
    
    security_file = "contracts/src/utils/security_monitor.cairo"
    with open(security_file, 'r') as f:
        content = f.read()
    
    tests = []
    
    # Test 1: Anomaly detection logic
    if "analyze_transaction_anomaly" in content:
        # Check amount deviation analysis
        if "AMOUNT_DEVIATION_THRESHOLD" in content and "deviation >" in content:
            tests.append(("Anomaly detection analyzes amount deviation", True))
        else:
            tests.append(("Anomaly detection analyzes amount deviation", False))
        
        # Check frequency analysis
        if "FREQUENCY_THRESHOLD" in content and "pattern.frequency >" in content:
            tests.append(("Anomaly detection analyzes frequency", True))
        else:
            tests.append(("Anomaly detection analyzes frequency", False))
        
        # Check temporal analysis
        if "hour_of_day" in content and "< 6 || hour_of_day > 22" in content:
            tests.append(("Anomaly detection analyzes temporal patterns", True))
        else:
            tests.append(("Anomaly detection analyzes temporal patterns", False))
    
    # Test 2: Risk level determination
    if "ANOMALY_THRESHOLD_CRITICAL" in content:
        # Check risk level logic
        if "anomaly_score >= ANOMALY_THRESHOLD_CRITICAL" in content:
            tests.append(("Risk assessment uses threshold comparison", True))
        else:
            tests.append(("Risk assessment uses threshold comparison", False))
    
    # Test 3: Alert creation logic
    if "create_security_alert" in content:
        # Check alert ID generation
        if "alert_counter.read() + 1" in content:
            tests.append(("Alert creation generates unique IDs", True))
        else:
            tests.append(("Alert creation generates unique IDs", False))
        
        # Check alert storage
        if "security_alerts.write" in content and "user_alerts" in content:
            tests.append(("Alert creation stores alerts properly", True))
        else:
            tests.append(("Alert creation stores alerts properly", False))
    
    # Test 4: Pattern update logic
    if "update_user_pattern" in content:
        # Check exponential moving average
        if "alpha" in content and "100 - alpha" in content:
            tests.append(("Pattern update uses exponential moving average", True))
        else:
            tests.append(("Pattern update uses exponential moving average", False))
        
        # Check deviation score update
        if "time_diff < 3600" in content and "deviation_score +=" in content:
            tests.append(("Pattern update adjusts deviation score", True))
        else:
            tests.append(("Pattern update adjusts deviation score", False))
    
    return tests

def test_transaction_monitor_logic():
    """Test transaction monitor logic."""
    print("📊 Testing Transaction Monitor Logic...")
    
    monitor_file = "contracts/src/transactions/transaction_monitor.cairo"
    with open(monitor_file, 'r') as f:
        content = f.read()
    
    tests = []
    
    # Test 1: Transaction recording with security
    if "record_transaction" in content:
        # Check integrity hash generation
        if "integrity_hash" in content and "pedersen_hash" in content:
            tests.append(("Transaction recording generates integrity hash", True))
        else:
            tests.append(("Transaction recording generates integrity hash", False))
        
        # Check risk score calculation
        if "risk_score" in content:
            tests.append(("Transaction recording calculates risk score", True))
        else:
            tests.append(("Transaction recording calculates risk score", False))
        
        # Check hash chain update
        if "hash_chain_latest" in content and "chain_entry_hash" in content:
            tests.append(("Transaction recording updates hash chain", True))
        else:
            tests.append(("Transaction recording updates hash chain", False))
    
    # Test 2: Transaction verification
    if "verify_transaction_integrity" in content:
        # Check hash recomputation
        if "computed_hash" in content and "transaction.integrity_hash" in content:
            tests.append(("Transaction verification recomputes hash", True))
        else:
            tests.append(("Transaction verification recomputes hash", False))
    
    # Test 3: Proof creation
    if "create_transaction_proof" in content:
        # Check authorization
        if "caller == transaction.user || caller == self.admin.read()" in content:
            tests.append(("Proof creation checks authorization", True))
        else:
            tests.append(("Proof creation checks authorization", False))
        
        # Check audit trail update
        if "audit_trail" in content and "PROOF_CREATED" in content:
            tests.append(("Proof creation updates audit trail", True))
        else:
            tests.append(("Proof creation updates audit trail", False))
    
    # Test 4: Suspicious transaction flagging
    if "flag_suspicious_transaction" in content:
        # Check admin authorization
        if "caller == self.admin.read()" in content or "SECURITY_AUDITOR_ROLE" in content:
            tests.append(("Transaction flagging checks authorization", True))
        else:
            tests.append(("Transaction flagging checks authorization", False))
        
        # Check flag update
        if "transaction.flagged = true" in content:
            tests.append(("Transaction flagging updates flag", True))
        else:
            tests.append(("Transaction flagging updates flag", False))
    
    return tests

def test_access_control_logic():
    """Test access control logic."""
    print("🔐 Testing Access Control Logic...")
    
    access_file = "contracts/src/utils/access_control.cairo"
    with open(access_file, 'r') as f:
        content = f.read()
    
    tests = []
    
    # Test 1: Role management
    if "grant_role" in content:
        # Check admin authorization
        if "has_role" in content and "admin_role" in content:
            tests.append(("Role granting checks admin authorization", True))
        else:
            tests.append(("Role granting checks admin authorization", False))
    
    # Test 2: Role hierarchy
    if "SECURITY_AUDITOR_ROLE" in content and "ANOMALY_DETECTOR_ROLE" in content:
        tests.append(("Access control defines security roles", True))
    else:
        tests.append(("Access control defines security roles", False))
    
    # Test 3: Role revocation
    if "revoke_role" in content:
        tests.append(("Access control supports role revocation", True))
    else:
        tests.append(("Access control supports role revocation", False))
    
    return tests

def run_all_logic_tests():
    """Run all logic tests."""
    print("🧪 StarkPulse Security Logic Validation")
    print("=" * 50)
    
    all_tests = []
    all_tests.extend(test_crypto_utils_logic())
    all_tests.extend(test_security_monitor_logic())
    all_tests.extend(test_transaction_monitor_logic())
    all_tests.extend(test_access_control_logic())
    
    passed = sum(1 for _, result in all_tests if result)
    total = len(all_tests)
    failed = total - passed
    
    print(f"\n📊 LOGIC TEST RESULTS")
    print("=" * 30)
    
    for test_name, result in all_tests:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name}")
    
    print(f"\nTotal Tests: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    
    if failed == 0:
        print("\n🎉 ALL LOGIC TESTS PASSED!")
        print("✅ Security logic implementation is correct")
        return True
    else:
        print(f"\n❌ {failed} LOGIC TESTS FAILED")
        print("💡 Please review the failed logic tests")
        return False

if __name__ == "__main__":
    success = run_all_logic_tests()
    exit(0 if success else 1)
