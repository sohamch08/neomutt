#!/usr/bin/env python3
"""Validate a Gmail app password and save it encrypted for newmutt."""

import getpass
import imaplib
import os
from pathlib import Path
import re
import ssl
import subprocess
import sys
import tempfile

account = "soham.chatterjee.cs@gmail.com"
destination = Path("/home/soham/.config/neomutt/gmail-app-password.gpg")
fingerprints = sys.argv[1].split() if len(sys.argv) == 2 else []
if len(fingerprints) != 1 or not re.fullmatch(r"[0-9A-Fa-f]{40,64}", fingerprints[0]):
    sys.exit("Pass exactly one fingerprint from your gpg-fingerprint alias.")

password = "".join(getpass.getpass(f"New app password for {account}: ").split())
if len(password) != 16:
    sys.exit("Expected 16 characters. Existing password file was not changed.")

try:
    with imaplib.IMAP4_SSL("imap.gmail.com", 993,
                          ssl_context=ssl.create_default_context(), timeout=20) as mailbox:
        mailbox.login(account, password)
except (OSError, imaplib.IMAP4.error) as error:
    sys.exit("Gmail login failed; existing file was not changed. "
             + str(error).replace(password, "[redacted]"))

encrypted = subprocess.run(
    ["gpg", "--encrypt", "--recipient", fingerprints[0]],
    input=password.encode(), stdout=subprocess.PIPE, check=True,
).stdout
temporary = None
try:
    with tempfile.NamedTemporaryFile(dir=destination.parent, prefix=".gmail-password-",
                                     delete=False) as output:
        temporary = Path(output.name)
        output.write(encrypted)
    os.replace(temporary, destination)
finally:
    if temporary is not None:
        temporary.unlink(missing_ok=True)
print("Gmail login succeeded. App password saved encrypted.")
