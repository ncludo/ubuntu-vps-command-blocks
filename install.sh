#!/usr/bin/env bash
# Enable/disable autostart only for this Unix user's interactive SSH Bash.
set -Eeuo pipefail
if (( $# != 2 )) || [[ "$1" != --profile && "$1" != --remove ]]; then
    printf 'Usage: ./install.sh --profile default|extended OR ./install.sh --remove yes\n' >&2
    exit 2
fi
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
python3 - "$HOME/.bashrc" "$root" "$1" "$2" <<'PYIN'
from pathlib import Path
import os, sys, shlex, stat, tempfile
rc=Path(sys.argv[1]); root=Path(sys.argv[2]); action=sys.argv[3]; value=sys.argv[4]
if action=='--profile' and value not in ('default','extended'):
    sys.exit('FAIL: profile must be default|extended')
if action=='--remove' and value!='yes':
    sys.exit('FAIL: use --remove yes')
if rc.is_symlink():
    sys.exit('FAIL: ~/.bashrc is a symlink; not modifying')
old=rc.read_text() if rc.exists() else ''
a='# >>> Command Blocks SSH autostart >>>'
b='# <<< Command Blocks SSH autostart <<<'
if old.count(a)!=old.count(b) or old.count(a)>1:
    sys.exit('FAIL: ambiguous .bashrc managed block')
if a in old:
    head,rem=old.split(a,1)
    _,tail=rem.split(b,1)
    old=head.rstrip('\n')+tail
if action=='--profile':
    command=shlex.quote(str(root/'command-blocks.bash'))
    block=('\n'+a+'\n'
       'if [[ $- == *i* && -n ${SSH_TTY:-} && -t 0 && -t 1 && -z ${CB_AUTOSTART_ACTIVE:-} ]]; then\n'
       f'    if [[ -f {command} ]]; then\n'
       f'        CB_AUTOSTART_ACTIVE=1 bash {command} --profile {value}\n'
       '    fi\n'
       'fi\n'+b+'\n')
    new=old.rstrip('\n')+'\n'+block
else:
    new=old.rstrip('\n')+'\n'
if new==(rc.read_text() if rc.exists() else ''):
    print('AUTOSTART: NO-OP')
    sys.exit(0)
fd,name=tempfile.mkstemp(prefix='.bashrc.cb.',dir=rc.parent)
try:
    mode=stat.S_IMODE(rc.stat().st_mode) if rc.exists() else 0o600
    os.fchmod(fd,mode)
    with os.fdopen(fd,'w') as f:
        f.write(new)
        f.flush(); os.fsync(f.fileno())
    import subprocess
    result=subprocess.run(['bash','-n',name],capture_output=True,text=True)
    if result.returncode:
        sys.exit('FAIL: .bashrc syntax: '+result.stderr)
    os.replace(name,rc)
    print('AUTOSTART: '+('INSTALLED '+value if action=='--profile' else 'REMOVED'))
finally:
    if os.path.exists(name): os.unlink(name)
PYIN
