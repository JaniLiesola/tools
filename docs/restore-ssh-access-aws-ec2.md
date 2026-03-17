# Quick Guide: Restore SSH Access to an AWS EC2 Instance
If the original SSH key is lost, you can regain access by pushing a new public key with EC2 Instance Connect (no rebuild needed).

## Prerequisites
- AWS CLI configured (`aws configure`) with permissions for `ec2-instance-connect:SendSSHPublicKey`
- Instance Connect supported AMI/agent (e.g., Amazon Linux 2/2023, many recent Ubuntu AMIs)
- Instance reachable on TCP 22 from your IP (security group/NACL allow)
- Instance ID, Availability Zone, OS username, and public IP/DNS

## Step 1: Generate a new key pair
Replace path/name if you prefer.
```bash
ssh-keygen -t ed25519 -f ~/.ssh/aws-ec2 -C "aws-ec2-access"
chmod 600 ~/.ssh/aws-ec2
```
- Produces private key (`~/.ssh/aws-ec2`) and public key (`~/.ssh/aws-ec2.pub`).

## Step 2: Push the public key with EC2 Instance Connect
Sends the public key to the instance's `~/.ssh/authorized_keys` for 60 seconds.
```bash
aws ec2-instance-connect send-ssh-public-key \
  --region <region> \
  --instance-id <instance-id> \
  --availability-zone <az> \
  --instance-os-user <os-user> \
  --ssh-public-key file://~/.ssh/aws-ec2.pub
```
- Common OS users: `ec2-user` (Amazon Linux), `ubuntu` (Ubuntu), `centos` (CentOS).
- If the command fails, verify IAM permissions, correct AZ, and that Instance Connect is supported/enabled on the AMI.

## Step 3: SSH with the new key
Run within 60 seconds of Step 2.
```bash
ssh -i ~/.ssh/aws-ec2 <os-user>@<public-ip-or-dns>
```
- If blocked, check security group/NACL for port 22 and instance state/public IP.

## Tips for key management
- Keep private keys in encrypted backups or a password manager.
- Use separate key pairs per environment (e.g., `aws-prod`, `aws-test`).
- Rotate by repeating Step 2 with a new public key.
