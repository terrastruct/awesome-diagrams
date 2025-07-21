#!/usr/bin/env python3
"""
Validate a single diagram.yml file against the required schema.

Usage: python3 ci/validate-yml.py path/to/diagram.yml
"""

import sys
import os
from urllib.parse import urlparse


def is_valid_url(url):
    try:
        result = urlparse(url)
        return all([result.scheme, result.netloc])
    except:
        return False


def validate(file_path):
    if not os.path.exists(file_path):
        print(f"❌ File does not exist: {file_path}")
        return False
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"❌ Error reading file: {e}")
        return False
    
    lines = content.split('\n')
    errors = []
    
    # Check required fields
    required = ['schema-version: 0.1', 'name:', 'images:', 'attribution:', 'tags:']
    for field in required:
        if not any(line.strip().startswith(field) for line in lines):
            errors.append(f"Missing: {field}")
    
    # Check attribution URL
    for line in lines:
        if line.strip().startswith('attribution:'):
            url = line.split(':', 1)[1].strip()
            if not is_valid_url(url):
                errors.append(f"Invalid URL: {url}")
    
    # Check images and tags have items
    for section in ['images', 'tags']:
        in_section = False
        has_items = False
        for line in lines:
            if line.strip().startswith(f'{section}:'):
                in_section = True
                continue
            if in_section and line.startswith('  - '):
                has_items = True
                break
            elif in_section and line.strip() and not line.startswith('  '):
                break
        if not has_items:
            errors.append(f"Empty {section} list")
    
    if errors:
        print("❌ Validation failed:")
        for error in errors:
            print(f"  - {error}")
        return False
    
    print("✅ Valid")
    return True


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 ci/validate-yml.py <diagram.yml>")
        sys.exit(1)
    
    if not validate(sys.argv[1]):
        sys.exit(1)