#!/usr/bin/env python
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
django.setup()

from django.core.validators import EmailValidator
from django.core.exceptions import ValidationError

validator = EmailValidator()
test_emails = [
    'testwood@gmail@gmail.com',
    'test@example.com',
    'invalid.email',
]

for email in test_emails:
    try:
        validator(email)
        print(f'✓ {email} is valid')
    except ValidationError as e:
        print(f'✗ {email} is invalid: {e.message}')
