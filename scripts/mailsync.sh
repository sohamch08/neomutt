#!/bin/sh
# Sync all IMAP accounts and update the Notmuch index.
mbsync -a 2>&1
notmuch new 2>&1
new_count=$(notmuch count tag:unread AND tag:inbox)
if [ "$new_count" -gt 0 ]; then
  notify-send "New mail" "$new_count unread messages"
fi
