#!/usr/bin/env bash
# Fix ownership of named-volume mount points before user-context setup runs.
#
# Docker named volumes mount root-owned on a fresh create, so the vscode user
# can't write to them — e.g. a pip install hits
#   PermissionError: [Errno 13] Permission denied: '/home/vscode/.cache/pip'
# This runs in onCreateCommand, which the dev container spec guarantees completes
# BEFORE postCreateCommand (object-form postCreate keys run in parallel, so a
# sibling key there would race; a postStart hook would fire too late). See dc-8yu.
#
# Only named-volume targets are listed. Bind mounts are excluded: they inherit
# host ownership, and .ssh/.env are readonly (chowning them would error).
set -u

# Target owner is always the container's dev user, regardless of whether this
# hook runs as vscode (normal) or root (some prebuild contexts) — so resolve
# paths and owner explicitly rather than from $HOME/$USER.
TARGET_USER="vscode"
USER_HOME="/home/${TARGET_USER}"

VOLUME_PATHS=(
  "${USER_HOME}/.cache/pip"
  "${USER_HOME}/.aws"
  "${USER_HOME}/.claude"
  "${USER_HOME}/.bash_history"
  "${USER_HOME}/.config/gh"
  "${USER_HOME}/.config/rbw"
  "${USER_HOME}/.dolt-server"
)

for path in "${VOLUME_PATHS[@]}"; do
  [ -e "$path" ] || continue
  owner="$(stat -c '%U' "$path" 2>/dev/null || echo '?')"
  if [ "$owner" != "$TARGET_USER" ]; then
    echo "fix-volume-perms: chown $path (was owned by '$owner')"
    sudo chown -R "${TARGET_USER}:${TARGET_USER}" "$path" || echo "WARN: chown $path failed"
  fi
done

echo "fix-volume-perms: done"
