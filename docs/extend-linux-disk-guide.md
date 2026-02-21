
# Linux Disk Expansion Guide

This guide provides step-by-step instructions for expanding disk space on a Linux server using LVM (Logical Volume Management).

## Prerequisites

- Root or sudo access
- LVM-managed storage system
- Basic knowledge of Linux disk management

## Step-by-Step Process

### 1. Check Current System Status

First, examine the current file system and storage configuration:

```bash
# Check the file system type and current partitions
lsblk -f
```

### 2. Verify LVM Configuration

Check available space in the volume group and logical volume status:

```bash
# Check if we have space in volume group
vgdisplay

# Check the status of the logical volume before resize
lvdisplay
```

### 3. Rescan Storage Devices

After adding new disk space (e.g., in VMware), rescan the devices:

```bash
# Rescan the devices to detect new space
echo 1 > /sys/block/sda/device/rescan
```

Verify the new space is detected:
```bash
# Check the file system type again
lsblk -f
```

### 4. Extend Partitions

Grow the partition to use available space:

```bash
# Extend partitions (replace <device> and <partition_number>)
growpart <device> <partition_number>

# Example with dry-run to test first:
sudo growpart /dev/sda 3 --dry-run

# Execute the actual resize:
sudo growpart /dev/sda 3
```

### 5. Extend Physical Volume

Resize the physical volume to use the expanded partition:

```bash
# Extend physical volume
pvresize <device>

# Example:
sudo pvresize /dev/sda3
```

### 6. Extend Logical Volume

Extend the logical volume using available space:

```bash
# Use all free space in volume group:
lvextend -l+100%FREE <logical_volume>
sudo lvextend -l+100%FREE /dev/ubuntu-vg/ubuntu-lv

# Or extend by specific amount:
lvextend -L+4G <logical_volume>
sudo lvextend -L+4G /dev/ubuntu-vg/ubuntu-lv
```

### 7. Extend File System

Finally, extend the file system to use the new space:

#### For XFS file systems:
```bash
sudo xfs_growfs /dev/ubuntu-vg/ubuntu-lv
```

#### For ext2/ext3/ext4 file systems:
```bash
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```

### 8. Verify Results

Check that the file system has been successfully expanded:

```bash
# Check available disk space
df -h
```

## Important Notes

- **Always backup** your data before performing disk operations
- Use `--dry-run` option when available to test commands first
- The exact device names (`/dev/sda3`, `/dev/ubuntu-vg/ubuntu-lv`) may vary in your system
- Ensure you're extending the correct logical volume and file system type

## Common Issues

- If `growpart` fails, the partition table might be GPT instead of MBR
- If `pvresize` fails, check that the partition was successfully extended
- File system type determines which resize command to use (`xfs_growfs` vs `resize2fs`)