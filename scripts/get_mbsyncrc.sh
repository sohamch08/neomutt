#!/usr/bin/env bash

set -e

DEFAULT_MAIL_PATH="$HOME/.mail/tifr"

echo -e "Enter TIFR username:\n (e.g. for john.doe@tifr.res.in, enter john.doe)"
read -rp "> " TIFR_USER_NAME
echo "User name: $TIFR_USER_NAME"

if [ -z "$TIFR_USER_NAME" ]; then
  echo -e "Error: Username cannot be empty.\n Retry"
  exit 1
fi

echo -e "Enter full folder path you want to store your mail\n[Default: $DEFAULT_MAIL_PATH, Press enter]"
read -rp "> " MAIL_PATH
if [ -z "$MAIL_PATH" ]; then
  MAIL_PATH="$DEFAULT_MAIL_PATH"
fi

case "$MAIL_PATH" in
"~" | '$HOME') MAIL_PATH="$HOME" ;;
"~/"*) MAIL_PATH="$HOME/${MAIL_PATH:2}" ;;
'$HOME/'*) MAIL_PATH="$HOME/${MAIL_PATH:6}" ;;
esac

echo "Mail Location to store: $MAIL_PATH"

export TIFR_USER_NAME
export MAIL_PATH

mkdir -p -- "$MAIL_PATH"
echo "Created $MAIL_PATH"

envsubst '$TIFR_USER_NAME $MAIL_PATH' <../mbsyncrc.tmpl >~/.mbsyncrc
echo -e "Generated .mbsyncrc file at $HOME/.mbsyncrc"
