
# check the file system type.
lsblk -f

# check if we have space in group volume 
vgdisplay

# check the status of the logical volume before resize
lvdisplay

# Rescan the devices
echo 1 > /sys/block/sda/device/rescan

# check the file system type.
lsblk -f 

# Extend partitions
growpart <device> <osio> # sudo growpart /dev/sda 3, sudo growpart /dev/sda 3 --dry-run

# Extend disk
pvresize <device> #sudo pvresize /dev/sda 3

lvextend -l+100%FREE <logical volume> # sudo lvextend -l+100%FREE /dev/ubuntu-vg/ubuntu-lv
lvextend -L+4G <LV> # sudo lvextend -L+4G /dev/ubuntu-vg/ubuntu-lv

# Extend file systems
xfs_growfs <LV> #  sudo xfs_growfs /dev/ubuntu-vg/ubuntu-lv # file systems xfs
resize2fs <LV> #  sudo resize2fs /dev/ubuntu-vg/ubuntu-lv # file systems: ext2, ext3, ext4

# check the file system type.
df -h
