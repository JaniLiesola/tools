# How to extend a disk in Windows using diskpart

<!--
This file contains documentation for the `diskpart` command-line utility. 
`diskpart` is used for disk partitioning tasks in Windows operating systems.
-->
diskpart

<!--
This markdown file contains a command for listing all disks on a system using the `diskpart` utility.
The `list disk` command displays all the disks connected to the computer, including information such as disk number, status, size, free space, and more.
-->
list disk

<!--
This script selects the disk with the identifier 16 using the diskpart utility.
Make sure to run this command with appropriate permissions and verify the disk identifier before executing to avoid unintended data loss.
-->
select disk 16

<!--
    This file contains a command to list all partitions on the selected disk using the diskpart utility.
-->
list partition

<!--
This command selects the second partition on the currently selected disk in DiskPart, a command-line disk partitioning utility in Windows. 
Selecting a partition allows you to perform various operations on it, such as formatting, assigning a drive letter, or setting it as active.
-->
select partition 2

<!-- 
    This command extends the volume or partition with focus to include unallocated space on the same disk. 
    It is used in disk management to increase the size of a volume.
-->
extend
