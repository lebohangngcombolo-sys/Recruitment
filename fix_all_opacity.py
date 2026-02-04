import os
import re

root_dir = r'c:\apps\Recruitment\khono_recruite\lib'
pattern = re.compile(r'\.withOpacity\s*\(\s*([^)]+)\s*\)')

count_files = 0
count_replacements = 0

print(f"Scanning {root_dir}...")

for dirpath, dirnames, filenames in os.walk(root_dir):
    for filename in filenames:
        if filename.endswith('.dart'):
            file_path = os.path.join(dirpath, filename)
            
            try:
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                matches = pattern.findall(content)
                if matches:
                    # print(f"Fixing {file_path} ({len(matches)} matches)")
                    new_content = pattern.sub(r'.withValues(alpha: \1)', content)
                    
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    
                    count_files += 1
                    count_replacements += len(matches)
            except Exception as e:
                print(f"Error processing {file_path}: {e}")

print(f"Finished. Fixed {count_files} files with {count_replacements} replacements.")
