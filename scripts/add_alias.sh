#!/usr/bin/env bash
set -euo pipefail

file="$HOME/.config/neomutt/modules/aliases.muttrc"

read -r -p "Alias: " alias
read -r -p "Email: " email
read -r -p "Full name: " name

printf "%-7s %-15s %-23s <%s>\n" alias "$alias" "$name" "$email" >>"$file"
