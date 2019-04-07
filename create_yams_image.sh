#!/bin/bash

#
# YAMS Image Creator
#

image_file="yams.img"
image_size="1024M"
mountpoint_ntfs="/mnt/ntfs"

disklabel_fat32='$ESP'
disklabel_ntfs='YAMS'

yams_grub2_repo="https://github.com/Sporesirius/grub.git"

function error() {
    echo -e "\\033[31;1m${@}\033[0m"
}

function warn() {
    echo -e "\\033[33;1m${@}\033[0m"
}

function info() {
    echo -e "\\033[32;1m${@}\033[0m"
}

# Check if sudo is installed
if sudo -v >/dev/null 2>&1; then
    sudo_prefix="sudo"
elif [ "`id -u`" != "0" ]; then
    error "Root or sudo privileges are required to run the install script!"
    exit 1
fi

echo "########################
 # YAMS image creator #
########################
"

# Make image
warn "Creating empty image (${image_size}) file."
$sudo_prefix fallocate -l $image_size $image_file
info "Image file created, DONE!"

# Create two paritions
warn "Make two paritions."
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << FDISK_CMDS  | $sudo_prefix fdisk $image_file
o      # Clear the in memory partition table
n      # ONE: New partition
p      # ONE: Primary partition
1      # ONE: Partition number 1
       # ONE: Default - start at beginning of disk 
+511M  # ONE: 511 MB NTFS partition
n      # TWO: New partition
p      # TWO: Primary partition
2      # TWO: Partion number 2
       # TWO: Default, start immediately after preceding partition
       # TWO: Default, extend partition to end of disk
a      # ONE: Make the partition bootable
1      # ONE: Mark partition one as bootable
a      # TWO: Make the partition bootable
2      # TWO: Mark partition two as bootable
t      # TWO: Change partition type
2      # TWO: Partition number 2
0xEF   # TWO: Mark partition one as ESP
p      # Print the in-memory partition table
w      # Write the partition table
q      # Quit
FDISK_CMDS
info "Two paritions created, DONE!"

# Extract kpartx output to array
kpartx="$($sudo_prefix kpartx -av $image_file)"
parts=$(grep -E -o 'loop[[:digit:]]+p[[:digit:]]+' <<<"$kpartx")

SAVEIFS=$IFS
IFS=$'\n'
parts=($parts)
IFS=$SAVEIFS

# Remove image from /dev/mapper
warn "Removing image from /dev/mapper"
$sudo_prefix kpartx -d $image_file
info "Image removed, DONE!"

# Add image to /dev/loop*
warn "Adding image to /dev/${parts}"
$sudo_prefix losetup -Pf $image_file
info "Image added, DONE!"

# Give the two paritions filesystems
warn 'Give partitions "one" NTFS and "two" FAT32 filesystems.'
$sudo_prefix mkfs.ntfs -L $disklabel_ntfs -Q /dev/${parts[0]}
$sudo_prefix mkfs.vfat -n $disklabel_fat32 -F 32 /dev/${parts[1]}
info "Filesystems created, DONE!"

# Mounting partition one (NTFS) to filesystem
warn "Mounting partition one (NTFS) to filesystem (${mountpoint_ntfs})."
$sudo_prefix mkdir -p $mountpoint_ntfs
$sudo_prefix mount /dev/${parts[0]} $mountpoint_ntfs
info "Partition one (NTFS) mountet, DONE!"


# Clone YAMS's GRUB 2
warn "Cloning YAMS's GRUB 2 from GitHub (${yams_grub2_repo})."
$sudo_prefix git clone $yams_grub2_repo
info "Cloned, DONE!"

# Compiling YAMS's GRUB 2
warn "Compiling YAMS's GRUB 2."
cd grub/
$sudo_prefix chmod 775 bootstrap
$sudo_prefix ./bootstrap
$sudo_prefix ./autogen.sh
$sudo_prefix ./configure
$sudo_prefix make
info "Compiled, DONE!"

image_loop=$(grep -E -o 'loop[[:digit:]]+' <<<"$kpartx")
array_image_loop=( $image_loop )

# Write YAMS'S GRUB 2 (i386-pc) to partition one (NTFS)
warn "Installing YAMS's GRUB 2 (i386-pc) to partition one (NTFS)."
$sudo_prefix ./grub-install --target=i386-pc --boot-directory=$mountpoint_ntfs/YAMS /dev/${array_image_loop[0]}
info "Installed, DONE!"

# Umounting partition one (NTFS) from filesystem
warn "Umounting partition one (NTFS) from filesystem (${mountpoint_ntfs})."
$sudo_prefix umount /dev/${parts[0]}
sleep 1 # System is too slow?
$sudo_prefix kpartx -d $image_file
info "Partition one (NTFS) unmountet, DONE!"

info "
########################################
 # YAMS image template created, DONE! #
########################################
"



