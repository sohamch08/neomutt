#!/usr/bin/env bash
set -euo pipefail
umask 077

dry_run=false

while getopts 'd' opt; do
  case "$opt" in
  d) dry_run=true ;;
  *)
    echo "Usage: $0 [-d] [backup|restore]" >&2
    exit 1
    ;;
  esac
done

shift "$((OPTIND - 1))"
action="${1:-backup}"

if [[ $# -gt 1 || ("$action" != backup && "$action" != restore) ]]; then
  echo "Usage: $0 [-d] [backup|restore]" >&2
  exit 1
fi

cd "$HOME/.config/neomutt"

check_file() {
  local file="$1"
  local input

  case "$action" in
  backup)
    input="$file"
    ;;
  restore)
    if [[ -e "$file" || -L "$file" ]]; then
      echo "SKIPPED: '$file' already exists."
      echo "Existing contacts were preserved. Restore only creates missing files."
      return 2
    fi

    input="$file.gpg"
    ;;
  *)
    echo "ERROR: Unknown action '$action'." >&2
    echo "Use 'backup' to encrypt contacts or 'restore' to recover missing files." >&2
    return 1
    ;;
  esac

  if [[ ! -e "$input" ]]; then
    echo "ERROR: Required input '$input' was not found in '$PWD'." >&2

    if [[ "$action" == backup ]]; then
      echo "Check where NeoMutt or abook saves this file and correct the script's path." >&2
      echo "If only its encrypted backup exists, run 'restore' first." >&2
    else
      echo "Recover '$input' from your repository or another backup, then retry." >&2
    fi

    return 1
  fi

  if [[ ! -f "$input" ]]; then
    echo "ERROR: '$input' is not a regular file." >&2
    echo "Check the path: it must point to the contact file, not a directory." >&2
    return 1
  fi

  if [[ ! -r "$input" ]]; then
    echo "ERROR: Your user cannot read '$input'." >&2
    echo "Check its owner and permissions with: ls -l -- '$input'" >&2
    return 1
  fi

  return 0
}

backup() {
  local file="$1"
  local temp="$2"

  if ! gpg --batch --yes --output "$temp" --encrypt "$file"; then
    echo "ERROR: GPG could not encrypt '$file'. See its diagnostic above." >&2
    echo "Check that gpg.conf specifies a valid default-recipient and its public key is available." >&2
    echo "This operation did not replace '$file.gpg'." >&2
    return 1
  fi

  if ! mv -fT -- "$temp" "$file.gpg"; then
    echo "ERROR: Encryption succeeded, but '$file.gpg' could not be replaced." >&2
    echo "Check destination-directory permissions, disk space, and whether the filesystem is read-only." >&2
    return 1
  fi

  return 0
}

restore() {
  local file="$1"
  local temp="$2"

  if ! gpg --yes --output "$temp" --decrypt "$file.gpg"; then
    echo "ERROR: GPG could not decrypt '$file.gpg'. See its diagnostic above." >&2
    echo "For public-key encryption, check that the matching private key is available and can be unlocked." >&2
    echo "For symmetric encryption, use the passphrase chosen when encrypting this backup." >&2
    echo "No working file was created at '$file'." >&2
    return 1
  fi

  if ! ln -T -- "$temp" "$file"; then
    echo "ERROR: Decryption succeeded, but '$file' could not be created." >&2
    echo "Check whether that path appeared while the script was running, or whether its directory is writable." >&2
    echo "The script will not overwrite an existing destination." >&2
    return 1
  fi

  return 0
}

failed=0

for file in modules/aliases.muttrc abook/addressbook; do
  # Check this file and capture the result.
  result=0
  check_file "$file" || result=$?

  case "$result" in
  0)
    # Input is usable; proceed.
    ;;
  2)
    # Existing restore destination; skip without failure.
    continue
    ;;
  *)
    # Input check failed.
    failed=1
    continue
    ;;
  esac

  # Preview without creating files or running GPG.
  if "$dry_run"; then
    echo "DRY RUN: Input checked; would $action $file"
    continue
  fi

  # Create a temporary destination.
  if ! temp=$(mktemp "${file}.tmp.XXXXXX"); then
    echo "ERROR: Cannot create temporary file for $file" >&2
    failed=1
    continue
  fi

  # Perform the chosen action and capture its result.
  result=0

  case "$action" in
  backup)
    backup "$file" "$temp" || result=$?
    ;;
  restore)
    restore "$file" "$temp" || result=$?
    ;;
  *)
    echo "ERROR: Unknown action: $action" >&2
    result=1
    ;;
  esac

  if [[ "$result" == 0 ]]; then
    echo "OK: $action completed for $file"
  else
    echo "ERROR: $action failed for $file" >&2
    failed=1
  fi

  # Clean up after success or a handled failure.
  if ! rm -f -- "$temp"; then
    echo "ERROR: Could not remove temporary file '$temp'." >&2
    echo "Check its permissions and remove it manually when possible." >&2

    if [[ "$action" == restore ]]; then
      echo "It may contain readable contact information." >&2
    fi

    failed=1
  fi
done

exit "$failed"
