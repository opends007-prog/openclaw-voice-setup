# Tailscale Setup Instructions

## Prerequisites

1. Tailscale account (sign up at https://tailscale.com/signup)
2. Admin access to your machines

## Installation

### On Mac M1

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start and authenticate
sudo tailscale up

# After authentication, get your IP
tailscale ip
# Should show something like: 100.x.y.z (your Mac's Tailscale IP)
```

### On Ubuntu VM

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start and authenticate (use same account as Mac)
sudo tailscale up

# After authentication, get your IP
tailscale ip
# Should show something like: 100.x.y.z (your VM's Tailscale IP)
```

## Configuration for This Setup

### Important: MACHINE IP ADDRESSES

In this setup, we rely on Tailscale IPs for reliable communication:
- **Mac** (running whisper-server): Should be `100.67.79.42` (as mentioned in your setup)
- **VM** (running voice transcriber and OpenClaw): Will get its own Tailscale IP

### Verifying Connection

From the VM, test connection to Mac:
```bash
# Replace with your Mac's actual Tailscale IP
ping 100.67.79.42
curl http://100.67.79.42:8080/
```

From Mac, test connection to VM:
```bash
# Replace with your VM's actual Tailscale IP
ping <VM_TAILSCALE_IP>
```

### Making Tailscale Start on Boot

#### On Mac:
Tailscale service installed by the installer should auto-start.

#### On Ubuntu VM:
```bash
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
```

## Troubleshooting

### Cannot Connect After Installation
1. Ensure you're logged into the same Tailscale account on both devices
2. Check firewall settings - Tailscale uses WireGuard (typically UDP 51820)
3. Try restarting Tailscale:
   - Mac: `sudo tailscale down` then `sudo tailscale up`
   - Ubuntu: `sudo systemctl restart tailscaled`

### IP Address Changes
Tailscale IPs are generally stable but can change if:
- You're removed and re-added to the tailnet
- The subnet manager reassigns IPs

To find current IPs:
- On any machine: `tailscale ip`
- To see all devices: `tailscale status`

### DNS Issues
If you can't resolve `tailscale` domains:
```bash
# Test Tailscale DNS
tailscale ping -c 4 google.com
```

## Updating Tailscale

```bash
# On both Mac and Ubuntu:
curl -fsSL https://tailscale.com/install.sh | sh
# Then restart:
sudo tailscale up  # Mac
sudo systemctl restart tailscaled  # Ubuntu
```