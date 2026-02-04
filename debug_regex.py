import re
import os

files = [
    r'c:\apps\Recruitment\khono_recruite\lib\screens\admin\interviews_list_screen.dart'
]

for file_path in files:
    print(f"Checking {file_path}")
    with open(file_path, 'rb') as f:
        content_bytes = f.read(200)
    
    print(f"Bytes: {content_bytes}")
    try:
        print(f"Decoded: {content_bytes.decode('utf-8')}")
    except Exception as e:
        print(f"Decode error: {e}")
