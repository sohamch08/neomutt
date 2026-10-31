#!/bin/sh
exec /usr/bin/python3 - <<'PY'
from datetime import datetime
import fcntl
import os
from pathlib import Path
import subprocess
import sys

os.umask(0o077)
os.environ["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

config = Path.home() / ".config/neomutt"
logs = config / "logs"
logs.mkdir(parents=True, exist_ok=True)

def log(message):
    timestamp = datetime.now().astimezone().isoformat(timespec="seconds")
    print(f"{timestamp} {message}", flush=True)

with (logs / "mailsync.lock").open("a") as lock:
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        log("Another sync is running; skipping.")
        sys.exit(0)

    log("Sync started.")
    try:
        subprocess.run(
            ["/opt/homebrew/bin/mbsync",
             "-c", str(config / "mbsyncrc"), "-a"],
            check=True,
        )
        subprocess.run(
            ["/opt/homebrew/bin/notmuch",
             f"--config={config / 'notmuch-config'}", "new"],
            check=True,
        )
    except subprocess.CalledProcessError as error:
        log(f"Sync failed: {error.cmd[0]} exited with {error.returncode}.")
        sys.exit(error.returncode)

    log("Sync completed.")
PY
