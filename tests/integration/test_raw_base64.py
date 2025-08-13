#!/usr/bin/env python3
"""
Test raw base64 image processing (CyberAI format)
"""

import requests
import base64
import json

# Read the icon file and convert to raw base64 (no data:image prefix)
with open("icon.png", "rb") as f:
    image_data = f.read()

# Convert to raw base64 string (what CyberAI sends)
raw_base64 = base64.b64encode(image_data).decode('utf-8')

print(f"🧪 Testing Raw Base64 Image Format (CyberAI-style)")
print(f"📏 Raw base64 length: {len(raw_base64)} characters")
print(f"🔍 First 50 chars: {raw_base64[:50]}...")

# Test the chat completions endpoint with raw base64
payload = {
    "model": "gemma-3n-e4b-it-mlx-8bit",
    "messages": [
        {
            "role": "user", 
            "content": [
                {"type": "text", "text": "What do you see in this image?"},
                {"type": "image_url", "image_url": {"url": raw_base64}}  # Raw base64, no prefix
            ]
        }
    ],
    "max_tokens": 100
}

try:
    print("🔄 Sending request to MLX-GUI server...")
    response = requests.post(
        "http://127.0.0.1:8000/v1/chat/completions",
        headers={"Content-Type": "application/json"},
        json=payload,
        timeout=60
    )
    
    if response.status_code == 200:
        result = response.json()
        message = result['choices'][0]['message']['content']
        print(f"✅ Success! Model response: {message}")
    else:
        print(f"❌ Failed with status {response.status_code}: {response.text}")
        
except Exception as e:
    print(f"❌ Error: {e}")