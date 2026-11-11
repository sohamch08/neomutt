[private]
default:
    @just --list

# Encrypt contacts, commit their backups without hooks, and push.
contact-bak:
    ./scripts/contacts-gpg.sh backup
    git -c core.hooksPath=/dev/null commit --only -m "updated database" -- modules/aliases.muttrc.gpg abook/addressbook.gpg
    git push

# Commit without running pre-commit or commit-msg hooks.
[positional-arguments]
cpost *args:
    git commit --no-verify "$@"

# Commit with all Git hooks disabled.
[positional-arguments]
cnobak *args:
    git -c core.hooksPath=/dev/null commit "$@"
