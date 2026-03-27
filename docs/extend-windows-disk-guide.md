# Windows Disk Expansion Guide

This guide provides step-by-step instructions for expanding disk space in Windows using `diskpart`.

## Prerequisites

- Local administrator privileges
- Unallocated space available on the same disk
- Basic understanding of Windows disk and partition management

## Step-by-Step Process

### 1. Open an Elevated Command Prompt

Start Command Prompt or PowerShell as Administrator, then open DiskPart:

```powershell
# Start DiskPart
diskpart
```

### 2. Check Current Disk Status

List disks and identify the one you need to extend:

```text
# List all disks
list disk
```

Select the target disk (replace `<disk_number>` with your disk number):

```text
# Select the target disk
select disk <disk_number>
```

### 3. Check Partitions on the Selected Disk

List partitions and identify the partition to extend:

```text
# List partitions on selected disk
list partition
```

Select the target partition (replace `<partition_number>` accordingly):

```text
# Select the target partition
select partition <partition_number>
```

### 4. Extend the Partition

Extend the selected partition to use all available unallocated space:

```text
# Extend to use all contiguous unallocated space
extend
```

Optional: extend by a specific amount in MB:

```text
# Extend by specific size in MB (example: 4096 MB)
extend size=4096
```

### 5. Verify Results

Confirm the partition size was updated:

```text
# Re-check partitions
list partition

# Re-check volumes
list volume
```

Exit DiskPart:

```text
exit
```

## Important Notes

- **Always back up** critical data before resizing partitions
- The `extend` command works only when unallocated space is contiguous and on the same disk
- Verify disk and partition numbers carefully before running `select` commands
- On system disks, some layouts (for example, recovery partitions between OS partition and free space) can block extension

## Common Issues

- If `extend` fails, check whether the unallocated space is directly after the target partition
- If the wrong disk or partition is selected, stop and re-run `list disk` and `list partition` to confirm
- If extension is blocked by partition layout, use Disk Management or third-party partition tools to move partitions first
