import re
import os

files = [
    r'c:\apps\Recruitment\khono_recruite\lib\screens\admin\interviews_list_screen.dart',
    r'c:\apps\Recruitment\khono_recruite\lib\screens\hiring_manager\hiring_manager_dashboard.dart'
]

pattern = re.compile(r'\.withOpacity\s*\(\s*([^)]+)\s*\)')

for file_path in files:
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        continue
        
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    matches = pattern.findall(content)
    print(f"File: {os.path.basename(file_path)}, Matches found: {len(matches)}")
    
    if len(matches) > 0:
        new_content = pattern.sub(r'.withValues(alpha: \1)', content)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file_path}")
    else:
        print(f"No changes needed for {file_path}")
