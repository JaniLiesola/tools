# Quick Guide: Restore SSH Access to an Azure VM
If the original SSH key is lost, you do not need to rebuild the VM. Create a new key pair, inject the public key into the VM, and connect with the new key.

## Prerequisites
- `az` CLI installed and logged in (`az login`)
- Resource group name, VM name, username, and the VM public IP/DNS

## Step 1: Generate a new key pair
Replace the path/name if you prefer.
```bash
ssh-keygen -t ed25519 -f ~/.ssh/azure-vm -C "azure-vm-access"
chmod 600 ~/.ssh/azure-vm
```
- Produces a private key (`~/.ssh/azure-vm`) and public key (`~/.ssh/azure-vm.pub`).

## Step 2: Inject the public key into the VM
Updates the user's `authorized_keys` without rebooting.
```bash
az vm user update \
  --resource-group <resource-group> \
  --name <vm-name> \
  --username <username> \
  --ssh-key-value ~/.ssh/azure-vm.pub
```
- Azure VM Agent writes the public key to `/home/<username>/.ssh/authorized_keys`.

## Step 3: Connect with the new key
```bash
ssh -i ~/.ssh/azure-vm <username>@<vm-ip-or-dns>
```
- Works immediately if firewall/NSG allows SSH (port 22).

## Tips for key management
- Keep private keys in backups (e.g., encrypted archive or password manager).
- Use separate key pairs per environment (e.g., `azure-prod`, `azure-test`).
- Rotate keys by repeating Step 2 with a new public key.
