#!/usr/bin/env bash
set -euo pipefail

# Local session on the Mac: talk to the daemon directly.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exec memoryd mcp
fi

# Bring up the tailnet once per session (userspace networking: no TUN
# device in the sandbox; state in memory: node key never touches disk).
if ! tailscale status >/dev/null 2>&1; then
  nohup tailscaled --tun=userspace-networking --socks5-server=localhost:1055 \
    --state=mem: >/tmp/tailscaled.log 2>&1 &
  for _ in $(seq 1 30); do
    tailscale up --auth-key="$TS_AUTHKEY" --hostname=ccweb 2>/dev/null && break
    sleep 1
  done
fi

key=/tmp/memoryd_ssh_key
if [ ! -f "$key" ]; then
  printf '%s' "$MEMORYD_SSH_KEY_B64" | base64 -d > "$key"
  chmod 600 "$key"
fi

# SSH rides the tailnet via tailscaled's SOCKS5 proxy, which also resolves
# the MagicDNS hostname. The forced command on the Mac runs `memoryd mcp`.
exec ssh -i "$key" \
  -o ProxyCommand="nc -X 5 -x 127.0.0.1:1055 %h %p" \
  -o StrictHostKeyChecking=accept-new \
  "$MEMORYD_SSH_USER@$MEMORYD_MAC_HOST"
