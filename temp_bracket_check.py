from pathlib import Path
p=Path(r'c:\apps\Recruitment\khono_recruite\lib\screens\hiring_manager\job_management.dart')
s=p.read_text()
stack=[]
pairs={')':'(',']':'[','}':'{'}
line=1
col=0
for i,ch in enumerate(s):
    if ch=='\n':
        line+=1; col=0; continue
    col+=1
    if ch in '([{':
        stack.append((ch,line,col))
    elif ch in ')]}':
        if not stack:
            print('Extra closing',ch,'at',line,col)
            break
        top,tl,tc=stack[-1]
        if top!=pairs[ch]:
            print('Mismatched closing',ch,'at',line,col,'expected matching for',top,'from',tl,tc)
            print('Current stack (top->bottom):')
            for item in reversed(stack):
                print(item)
            break
        stack.pop()
else:
    if stack:
        ch,tl,tc=stack[-1]
        print('Unclosed opening',ch,'at',tl,tc)
    else:
        print('All balanced')
