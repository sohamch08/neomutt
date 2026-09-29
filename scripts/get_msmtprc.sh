#!/usr/bin/env bash

set -e

echo -e "Enter TIFR username:\n (e.g. for john.doe@tifr.res.in, enter john.doe)"
read -rp "> " TIFR_USER_NAME
echo "User name: $TIFR_USER_NAME"

if [ -z "$TIFR_USER_NAME" ]; then
  echo -e "Error: Username cannot be empty.\n Retry"
  exit 1
fi

export TIFR_USER_NAME

envsubst '$TIFR_USER_NAME' <templates/msmtprc.tmpl >~/.msmtprc
echo -e "Generated .msmtprc file at $HOME/.msmtprc"
