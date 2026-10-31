#!/bin/sh
set -eu

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

config="$HOME/.config/neomutt"
plist="$HOME/Library/LaunchAgents/local.neomutt.mailsync.plist"
service="gui/$(id -u)/local.neomutt.mailsync"

test "$(uname -s)" = Darwin
test -f "$config/scripts/mailsync.sh"

for program in python3 mbsync notmuch pass gpg; do
  command -v "$program" >/dev/null
done

chmod 700 "$config/scripts/mailsync.sh"

/usr/bin/python3 - <<'PY'
from datetime import datetime
from pathlib import Path
import plistlib
import shutil

home = Path.home()
config = home / ".config/neomutt"
agents = home / "Library/LaunchAgents"
logs = config / "logs"
backups = logs / "setup-backups"

agents.mkdir(parents=True, exist_ok=True)
backups.mkdir(parents=True, exist_ok=True)
logs.chmod(0o700)
backups.chmod(0o700)

destination = agents / "local.neomutt.mailsync.plist"

if destination.exists():
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    shutil.copy2(destination, backups / f"mailsync-{stamp}.plist")

settings = {
    "Label": "local.neomutt.mailsync",
    "ProgramArguments": [str(config / "scripts/mailsync.sh")],
    "RunAtLoad": True,
    "StartCalendarInterval": [
        {"Minute": minute} for minute in range(0, 60, 5)
    ],
    "EnvironmentVariables": {
        "HOME": str(home),
        "PATH": "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "PASSWORD_STORE_GPG_OPTS": "--batch --pinentry-mode error",
    },
    "StandardOutPath": str(logs / "mailsync.log"),
    "StandardErrorPath": str(logs / "mailsync.error.log"),
    "Umask": 63,
}

temporary = destination.with_suffix(".plist.tmp")
with temporary.open("wb") as output:
    plistlib.dump(settings, output)
temporary.chmod(0o600)
temporary.replace(destination)
PY

plutil -lint "$plist"

if launchctl print "$service" >/dev/null 2>&1; then
  launchctl bootout "$service"
fi

launchctl bootstrap "gui/$(id -u)" "$plist"

printf '%s\n' \
  "Mail syncing enabled every five minutes." \
  "Log: $config/logs/mailsync.log"
