#!/bin/bash
# Set worker hostname from the 'k8s-hostname=' kernel arg.
# No arg (e.g. the VM host, not a PXE worker) -> leave hostname untouched.

HOST="$(sed -n 's/.*k8s-hostname=\([^ ]*\).*/\1/p' /proc/cmdline 2>/dev/null)"
[ -n "$HOST" ] || exit 0

# Wait up to 60s for the whole-root overlay to be up and /etc/hostname writable.
for i in $(seq 1 60); do
    mount | grep -qE '/ on .* overlay' && [ -w /etc/hostname ] && break
    sleep 1
done

# Live hostname (CAP_SYS_ADMIN — service runs as root).
hostname "$HOST"
rc=$?

# Persist only once the overlay makes /etc/hostname writable.
if [ -w /etc/hostname ]; then
    printf '%s\n' "$HOST" > /etc/hostname
    rc=$?
fi

exit "$rc"