from pathlib import Path
p=Path(r'c:\apps\Recruitment\khono_recruite\lib\screens\hiring_manager\job_management.dart')
lines=p.read_text().splitlines()
ln=1094
line=lines[ln-1]
print(f"Line {ln}: {line!r}")
for i,ch in enumerate(line, start=1):
    print(f"{i:3}: {ch!r}")
