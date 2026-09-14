#!/bin/bash
# Removes AIV: the launchd service, installed files, service user, and
# the pkg receipt. flat .pkg installers have no built-in uninstaller,
# so this script ships inside the package as the supported removal path.
set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

PLIST=/Library/LaunchDaemons/com.aivhub.aiv.plist
UNIVERSALAUTH_PLIST=/Library/LaunchDaemons/com.aivhub.aiv_universalauth.plist

if [ -f "$PLIST" ]; then
  launchctl bootout system "$PLIST" 2>/dev/null || launchctl unload -w "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
fi

if [ -f "$UNIVERSALAUTH_PLIST" ]; then
  launchctl bootout system "$UNIVERSALAUTH_PLIST" 2>/dev/null || launchctl unload -w "$UNIVERSALAUTH_PLIST" 2>/dev/null || true
  rm -f "$UNIVERSALAUTH_PLIST"
fi

rm -rf /usr/local/lib/aiv
rm -rf /usr/local/var/log/aiv
rm -f /usr/local/bin/aiv
rm -f /usr/local/bin/aiv_universalauth
rm -f /usr/local/bin/aiv-uninstall.sh

if dscl . -read /Users/_aiv >/dev/null 2>&1; then
  dscl . -delete /Users/_aiv
fi

pkgutil --forget com.aivhub.aiv >/dev/null 2>&1 || true

echo "AIV has been uninstalled."
