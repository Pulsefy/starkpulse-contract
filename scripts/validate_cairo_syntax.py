#!/usr/bin/env python3
"""
StarkPulse Cairo Syntax Validator
This script validates the syntax of our Cairo files without requiring scarb.
"""

import os
import re
import sys
from pathlib import Path

def validate_cairo_file(file_path):
    """Validate basic Cairo syntax in a file."""
    errors = []
    warnings = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')
    
    # Check for basic syntax issues
    brace_count = 0
    paren_count = 0
    bracket_count = 0
    in_comment = False
    
    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        
        # Skip empty lines
        if not stripped:
            continue
            
        # Handle comments
        if stripped.startswith('//'):
            continue
        if '/*' in stripped:
            in_comment = True
        if '*/' in stripped:
            in_comment = False
            continue
        if in_comment:
            continue
            
        # Count braces, parentheses, brackets
        brace_count += line.count('{') - line.count('}')
        paren_count += line.count('(') - line.count(')')
        bracket_count += line.count('[') - line.count(']')
        
        # Check for common syntax issues
        if stripped.endswith(',') and not any(keyword in stripped for keyword in ['struct', 'enum', 'impl', 'trait']):
            if not re.search(r'(Array|Map|felt252|u\d+|bool|ContractAddress)', stripped):
                warnings.append(f"Line {line_num}: Trailing comma might be unnecessary")
        
        # Check for missing semicolons (basic check)
        if (stripped.endswith(')') or stripped.endswith('}')) and not stripped.endswith(';') and not stripped.endswith(','):
            if any(keyword in stripped for keyword in ['let ', 'assert', 'self.']):
                if not any(keyword in stripped for keyword in ['fn ', 'struct ', 'enum ', 'impl ', 'trait ', 'mod ', 'use ']):
                    warnings.append(f"Line {line_num}: Missing semicolon?")
        
        # Check for proper use statements
        if stripped.startswith('use ') and not stripped.endswith(';'):
            errors.append(f"Line {line_num}: Use statement missing semicolon")
        
        # Check for proper function definitions
        if 'fn ' in stripped and not stripped.startswith('//'):
            if not re.search(r'fn\s+\w+\s*\(', stripped):
                warnings.append(f"Line {line_num}: Function definition might be malformed")
    
    # Check for unmatched braces/parentheses
    if brace_count != 0:
        errors.append(f"Unmatched braces: {brace_count} extra opening braces")
    if paren_count != 0:
        errors.append(f"Unmatched parentheses: {paren_count} extra opening parentheses")
    if bracket_count != 0:
        errors.append(f"Unmatched brackets: {bracket_count} extra opening brackets")
    
    # Check for required Cairo patterns
    if '#[starknet::contract]' in content:
        if 'mod ' not in content:
            errors.append("Contract missing module definition")
        if '#[storage]' not in content:
            warnings.append("Contract missing storage struct")
        if '#[constructor]' not in content:
            warnings.append("Contract missing constructor")
    
    if '#[starknet::interface]' in content:
        if 'trait ' not in content:
            errors.append("Interface missing trait definition")
    
    return errors, warnings

def validate_project_structure():
    """Validate the overall project structure."""
    errors = []
    warnings = []
    
    # Check for required files
    required_files = [
        'contracts/src/lib.cairo',
        'contracts/src/utils/access_control.cairo',
        'contracts/src/utils/crypto_utils.cairo',
        'contracts/src/utils/security_monitor.cairo',
        'contracts/src/interfaces/i_transaction_monitor.cairo',
        'contracts/src/interfaces/i_security_monitor.cairo',
        'contracts/src/transactions/transaction_monitor.cairo',
    ]
    
    for file_path in required_files:
        if not os.path.exists(file_path):
            errors.append(f"Missing required file: {file_path}")
    
    # Check lib.cairo for proper module declarations
    lib_path = 'contracts/src/lib.cairo'
    if os.path.exists(lib_path):
        with open(lib_path, 'r') as f:
            lib_content = f.read()
        
        required_modules = [
            'pub mod crypto_utils;',
            'pub mod security_monitor;',
            'pub mod i_security_monitor;'
        ]
        
        for module in required_modules:
            if module not in lib_content:
                warnings.append(f"lib.cairo missing module declaration: {module}")
    
    return errors, warnings

def main():
    """Main validation function."""
    print("🔍 StarkPulse Cairo Syntax Validator")
    print("=" * 50)
    
    # Validate project structure
    print("\n📁 Validating project structure...")
    struct_errors, struct_warnings = validate_project_structure()
    
    if struct_errors:
        print("❌ Structure Errors:")
        for error in struct_errors:
            print(f"  - {error}")
    
    if struct_warnings:
        print("⚠️  Structure Warnings:")
        for warning in struct_warnings:
            print(f"  - {warning}")
    
    if not struct_errors and not struct_warnings:
        print("✅ Project structure looks good!")
    
    # Find all Cairo files
    cairo_files = []
    for root, dirs, files in os.walk('contracts/src'):
        for file in files:
            if file.endswith('.cairo'):
                cairo_files.append(os.path.join(root, file))
    
    print(f"\n📄 Found {len(cairo_files)} Cairo files to validate...")
    
    total_errors = 0
    total_warnings = 0
    
    # Validate each Cairo file
    for file_path in sorted(cairo_files):
        print(f"\n🔍 Validating {file_path}...")
        
        try:
            errors, warnings = validate_cairo_file(file_path)
            
            if errors:
                print(f"❌ Errors in {file_path}:")
                for error in errors:
                    print(f"  - {error}")
                total_errors += len(errors)
            
            if warnings:
                print(f"⚠️  Warnings in {file_path}:")
                for warning in warnings:
                    print(f"  - {warning}")
                total_warnings += len(warnings)
            
            if not errors and not warnings:
                print(f"✅ {file_path} looks good!")
                
        except Exception as e:
            print(f"❌ Error reading {file_path}: {e}")
            total_errors += 1
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 VALIDATION SUMMARY")
    print("=" * 50)
    print(f"Files validated: {len(cairo_files)}")
    print(f"Total errors: {total_errors}")
    print(f"Total warnings: {total_warnings}")
    
    if total_errors == 0:
        print("🎉 No syntax errors found!")
        if total_warnings == 0:
            print("🌟 Perfect! No warnings either!")
        else:
            print(f"💡 {total_warnings} warnings found - consider reviewing them")
        return 0
    else:
        print(f"🚨 {total_errors} errors found - please fix them before deployment")
        return 1

if __name__ == "__main__":
    sys.exit(main())
