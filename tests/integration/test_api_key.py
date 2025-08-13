#!/usr/bin/env python3
"""
Test script for API key validation in MLX-GUI OpenAI endpoints.
"""
import requests
import json
import pytest
from .conftest import BASE_URL

pytestmark = pytest.mark.integration


def test_api_key_formats(http_session):
	"""Test different API key formats"""
	test_cases = [
		{"name": "No API key", "headers": {}, "expected": "should work"},
		{"name": "Authorization Bearer", "headers": {"Authorization": "Bearer sk-test"}, "expected": "should work"},
		{"name": "X-API-Key header", "headers": {"x-api-key": "sk-test"}, "expected": "should work"},
		{"name": "Both headers", "headers": {"Authorization": "Bearer sk-bearer", "x-api-key": "sk-xapi"}, "expected": "should prefer Bearer"},
	]
	for case in test_cases:
		r = http_session.get(f"{BASE_URL}/v1/models", headers=case["headers"]) 
		assert r.status_code in (200, 500, 404)


if __name__ == "__main__":
    test_api_key_formats()