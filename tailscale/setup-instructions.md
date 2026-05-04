# Tailscale Setup Instructions

Tailscale creates a secure, private network between your Mac and VM so the voice transcriber can reach whisper-server.

## Prerequisites

1. Tailscale account (sign up at https://tailscale.com/signup)
2. Admin access to both machines

## Installation

### On Mac

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### On Ubuntu VM

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Both machines must authenticate with the **same Tailscale account**.

## Find Your Tailscale IPs

On **each** machine, run:

```bash
tailscale ip
```

Note the output:

| Machine | Example IP | What to do with it |
|---|---|---|
| **Mac** (runs whisper-server) | `100.x.y.z` | Enter this in the VM's `.env` as `WHISPER_API_URL` |
| **VM** (runs bots) | `100.x.y.z` | Not needed for this setup |

## Verify Connection

From the VM, test connectivity to the Mac:

```bash
# Ping the Mac
ping <MAC_TAILSCALE_IP>

# Test whisper-server (after Mac setup is complete)
curl http://<MAC_TAILSCALE_IP>:8080/
```

From the Mac, test connectivity to the VM:

```bash
ping <VM_TAILSCALE_IP>
```

## Enable on Boot

Tailscale should auto-start by default after installation. To verify:

```bash
# On Mac:
sudo launchctl list | grep tailscale

# On Ubuntu VM:
sudo systemctl status tailscaled
```

## Troubleshooting

### Cannot connect

1. Verify both machines show up in `tailscale status`
2. Check they're on the same tailnet (same account)
3. Restart Tailscale:
   - Mac: `sudo tailscale down && sudo tailscale up`
   - VM: `sudo systemctl restart tailscaled && sudo tailscale up`

### IP address changes

Tailscale IPs are generally stable but can change if a machine is removed and re-added to the tailnet. Always check with `tailscale ip` after re-authentication.

### Firewall issues

Tailscale uses WireGuard (UDP). If you have a strict firewall, ensure UDP traffic is allowed on the Tailscale interface.