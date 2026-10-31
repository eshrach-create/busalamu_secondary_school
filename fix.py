import re
with open('lib/main.dart','r',encoding='utf-8',errors='ignore') as f:
    s=f.read()
# Fix setState patterns like setState((){xxx); -> setState((){xxx;});
s=re.sub(r'setState\(\(\)\{([^}]*?)\);', lambda m: f"setState((){{{m.group(1).rstrip(';')};}});", s)
s=re.sub(r'setS\(\(\)\{([^}]*?)\);', lambda m: f"setS((){{{m.group(1).rstrip(';')};}});", s)
# Fix onChanged patterns like (v){setState((){x=v!)), -> (v){setState((){x=v!;}),
s=re.sub(r'setState\(\(\)\{([^}]*?)\),', lambda m: f"setState((){{{m.group(1).rstrip(';')};}}),", s)
s=re.sub(r'setS\(\(\)\{([^}]*?)\),', lambda m: f"setS((){{{m.group(1).rstrip(';')};}}),", s)
# Fix Navigator.pop
s=s.replace('Navigator.pop(ctx), child:', 'Navigator.pop(ctx);}, child:')
s=s.replace('Navigator.pop(c,false), child:', 'Navigator.pop(c,false);}, child:')
s=s.replace('Navigator.pop(c,true), child:', 'Navigator.pop(c,true);}, child:')
s=s.replace('Navigator.pop(x), child:', 'Navigator.pop(x);}, child:')
s=s.replace(', scanSuccess=', '; scanSuccess=')
s=s.replace(', isProcessing=', '; isProcessing=')
# Fix common broken onChanged: .text=v!)), -> .text=v!;}),
s=re.sub(r'\.text=v!\)\),', '.text=v!;}),', s)
with open('lib/main.dart','w',encoding='utf-8') as f:
    f.write(s)
print('AUTO FIXED')
