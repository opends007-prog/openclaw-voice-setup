# Orbstack VM Setup Instructions

## Prerequisites

1. Orbstack installed on your Mac M1
   - Download from: https://orbstack.dev
   - Install via: `brew install --cask orbstack` or download directly

## Creating the Ubuntu VM

### Method 1: Using Orbstack GUI

1. Open Orbstack application
2. Click "+" → "New VM"
3. Select "Ubuntu 22.04 LTS" as the image
4. Configure VM settings:
   - Name: `openclaw-voice-vm` (or any name you prefer)
   - Memory: 2GB minimum (4GB recommended)
   - Disk: 10GB minimum
   - CPUs: 2 cores minimum
5. Click "Create"

### Method 2: Using Orbstack CLI

```bash
# List available images
orbctl vm images

# Create Ubuntu 22.04 VM
orbctl vm create openclaw-voice-vm \
  --image ubuntu:22.04 \
  --memory 4GB \
  --disk 10GB \
  --cpus 2
```

## Accessing the VM

### Via Orbstack GUI
- Select your VM in Orbstack
- Click "Shell" to open a terminal

### Via SSH
```bash
# Get VM IP address
orbctl vm list

# SSH into VM (default user is usually 'ubuntu')
ssh ubuntu@<VM_IP_ADDRESS>
# Password: ubuntu (or check Orbstack docs for default credentials)
```

## Setting Up Shared Folder (Optional)

To easily copy files between Mac and VM:

1. In Orbstack, select your VM
2. Click "Settings" → "Shared Folders"
3. Add a shared folder pointing to this repository on your Mac
4. The folder will be accessible in the VM at `/mnt/shared` or similar

## Post-Creation Steps

Once you have access to the Ubuntu VM:

1. Update and upgrade the system:
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

2. Clone this repository (if not using shared folder):
   ```bash
   git clone <your-repository-url>
   cd openclaw-voice-setup/vm
   ```

3. Continue with the VM setup:
   ```bash
   chmod +x setup.sh
   sudo ./setup.sh
   ```

4. Install and configure Tailscale (see tailscale/setup-instructions.md)

## Troubleshooting

### VM Won't Start
- Check Orbstack logs: Help → Show Logs
- Ensure virtualization is enabled in Mac Security Settings
- Try restarting Orbstack application

### Cannot SSH to VM
- Verify VM is running in Orbstack
- Check IP address with `orbctl vm list`
- Ensure SSH service is running: `orbctl vm ssh <vm-name> -- sudo systemctl status ssh`

### Performance Issues
- Allocate more RAM/CPUs in VM settings
- Consider using VirtioFS for better file sharing performance