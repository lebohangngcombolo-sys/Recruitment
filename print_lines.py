from pathlib import Path
p=Path(r'c:\apps\Recruitment\khono_recruite\lib\screens\hiring_manager\job_management.dart')
lines=p.read_text().splitlines()
for i in range(1086,1100):
    print(f"{i+1:5}: {lines[i]}")
