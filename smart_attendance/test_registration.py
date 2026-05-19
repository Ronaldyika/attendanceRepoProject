#!/usr/bin/env python
"""
Test script to reproduce the 500 error from Flutter
"""
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from django.test import Client
import json

client = Client()

test_cases = [
    {
        'name': 'Invalid email (two @ symbols)',
        'data': {
            'email': 'testwood@gmail@gmail.com',
            'first_name': 'test1',
            'last_name': 'test1',
            'registration_number': 'uba25eoo11',
            'role': 'student',
            'password': 'TestPass123',
            'password_confirm': 'TestPass123',
        }
    },
    {
        'name': 'Valid registration',
        'data': {
            'email': 'valid@example.com',
            'first_name': 'Valid',
            'last_name': 'User',
            'registration_number': 'validreg001',
            'role': 'student',
            'password': 'ValidPass123',
            'password_confirm': 'ValidPass123',
        }
    },
    {
        'name': 'Missing password',
        'data': {
            'email': 'test@example.com',
            'first_name': 'Test',
            'last_name': 'User',
            'registration_number': 'test001',
            'role': 'student',
            'password_confirm': 'TestPass123',
        }
    },
]

for test in test_cases:
    print(f"\n{'='*60}")
    print(f"TEST: {test['name']}")
    print(f"{'='*60}")
    
    response = client.post(
        '/api/v1/auth/register/',
        data=json.dumps(test['data']),
        content_type='application/json'
    )
    
    print(f"Status Code: {response.status_code}")
    print(f"Response: {response.content.decode()}")
    
    if response.status_code >= 500:
        print("ERROR: Got 500 status!")
