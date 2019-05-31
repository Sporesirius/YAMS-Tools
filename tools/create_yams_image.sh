#!/bin/bash

#
# YAMS image creator
#

# Configure variables
declare_variables() {
    yams_grub2_repo="https://github.com/Sporesirius/grub2.git"
    yams_preloader_repo="https://github.com/Sporesirius/PreLoader.git"
    #yams_uefi_ntfs_repo="https://github.com/Sporesirius/uefi-ntfs.git"

    image_file="yams.img"
    image_size="1024M"
    mountpoint_ntfs="/mnt/ntfs"
    mountpoint_fat32="/mnt/fat32"

    disklabel_ntfs='YAMS'
    disklabel_fat32='$ESP'
    
    # Colour codes
    colour_red="\e[31m"
    colour_green="\e[32m"
    colour_yellow="\e[33m"
    colour_cyan="\e[36m"
    colour_reset="\e[0m"    
}

# Colour to function
function error() {
    echo -e "${colour_red}"
    echo -e "${colour_red}Exiting!${colour_reset}"
    exit 1
}

# Neat loading animation
show_loading() {
    local pid=$!
    local loading_text=$1

    echo -ne "${colour_yellow}  $loading_text${colour_reset}\r"

    while kill -0 $pid 2>/dev/null; do
        echo -ne "${colour_yellow}  $loading_text.${colour_reset}\r"
        sleep 0.5
        echo -ne "${colour_yellow}  $loading_text..${colour_reset}\r"
        sleep 0.5
        echo -ne "${colour_yellow}  $loading_text...${colour_reset}\r"
        sleep 0.5
        echo -ne "\r\033[K"
        echo -ne "${colour_yellow}  $loading_text${colour_reset}\r"
        sleep 0.5
    done

    echo -e "${colour_green}$loading_text...FINISHED${colour_reset}"
}

# Image creation and stuff like that
function create_image {
    $sudo_prefix fallocate -l $image_size $image_file
}

function make_parition {
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << FDISK_CMDS | $sudo_prefix fdisk $image_file
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
t      # TWO: Change partition type
2      # TWO: Partition number 2
0xEF   # TWO: Mark partition two as ESP
p      # Print the in-memory partition table
w      # Write the partition table
q      # Quit
FDISK_CMDS

# Set hidden flag
#sudo parted $image_file set 2 hidden on

}

function give_parition_filesystem {
	$sudo_prefix mkfs.ntfs -L $disklabel_ntfs -Q /dev/${parts[0]}
	$sudo_prefix mkfs.vfat -n $disklabel_fat32 -F 32 /dev/${parts[1]}
}

# All un/mount, un/map and un/loop devices
function map_device {
    local kpartx="$($sudo_prefix kpartx -av $image_file)"
    local parts=$(grep -E -o 'loop[[:digit:]]+p[[:digit:]]+' <<<"$kpartx")
    
    echo "$parts"
}

function unmap_device() {
    $sudo_prefix kpartx -d $image_file
}

function add_loop_device() {
    $sudo_prefix losetup -Pf $image_file
}

function mount_filesystem() {
    local mountpoint=$1
    local partition=$2
    $sudo_prefix mkdir -p $mountpoint
    $sudo_prefix mount /dev/$partition $mountpoint
}

function unmount_filesystem() {
    local partition=$1
    $sudo_prefix umount /dev/$partition
}

# Cloning, compiling and installing
function clone_repo() {
    $sudo_prefix git clone --branch newtest $yams_grub2_repo # --branch test
    $sudo_prefix git clone $yams_preloader_repo
    #$sudo_prefix git clone $yams_uefi_ntfs_repo
}

function setup_grub2() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix chmod 775 bootstrap
    $sudo_prefix ./bootstrap
    $sudo_prefix ./autogen.sh
	$sudo_prefix mkdir -p $mountpoint_fat32/EFI/GRUB
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

# i386-pc
function compile_grub2_i386-pc() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
	$sudo_prefix ./linguas.sh
    $sudo_prefix ./configure --with-platform=pc --target=i386 --disable-werror
    $sudo_prefix make
    $sudo_prefix make install
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

function install_grub2_i386-pc() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./grub-install --target=i386-pc --compress=gz --no-floppy --verbose --recheck --boot-directory=$mountpoint_ntfs/YAMS /dev/$image_loop
    sleep 20
    $sudo_prefix make clean
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

# i386-efi
function compile_grub2_i386-efi() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./configure --with-platform=efi --target=i386 --disable-werror
    $sudo_prefix make
    $sudo_prefix make install
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

function install_grub2_i386-efi() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./grub-install --target=i386-efi  --compress=gz --removable --verbose --recheck --modules=ntfs.mod --boot-directory=$mountpoint_ntfs/YAMS --efi-directory=$mountpoint_fat32
    sleep 20
    $sudo_prefix make clean
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

# x86_64-efi
function compile_grub2_x86_64-efi() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./configure --with-platform=efi --target=x86_64 --disable-werror
    $sudo_prefix make
    $sudo_prefix make install
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

function install_grub2_x86_64-efi() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./grub-install --target=x86_64-efi --compress=gz --removable --verbose --recheck --modules=ntfs.mod --boot-directory=$mountpoint_ntfs/YAMS --efi-directory=$mountpoint_fat32
    sleep 20
    $sudo_prefix make clean
	$sudo_prefix make distclean
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}
  
# arm-efi
function compile_grub2_arm-efi() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./configure --with-platform=efi --target=arm-linux-gnueabihf --disable-werror
    $sudo_prefix make
    $sudo_prefix make install
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

function install_grub2_arm-efi() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./grub-install --target=arm-efi  --compress=gz --removable --verbose --recheck --modules=ntfs.mod --boot-directory=$mountpoint_ntfs/YAMS --efi-directory=$mountpoint_fat32
    sleep 20
    $sudo_prefix make clean
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

# arm64-efi
function compile_grub2_arm64-efi() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./configure --with-platform=efi --target=aarch64-linux-gnu --disable-werror
    $sudo_prefix make
    $sudo_prefix make install
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}

function install_grub2_arm64-efi() {
    echo -e "${colour_cyan}Switching to GRUB 2 folder.${colour_reset}"
    cd grub2/
    $sudo_prefix ./grub-install --target=arm64-efi --compress=gz --removable --verbose --recheck --modules=ntfs.mod --boot-directory=$mountpoint_ntfs/YAMS --efi-directory=$mountpoint_fat32
    sleep 20
    $sudo_prefix make clean
	$sudo_prefix make distclean
    echo -e "${colour_cyan}Switching back to YAMS folder.${colour_reset}"
    cd ..
}


main() {
    # First of all we have to check if we have enough rights to use the script sensibly
    if sudo -v >/dev/null 2>&1; then
        sudo_prefix="sudo"
    elif [ "`id -u`" != "0" ]; then
        error "Root or sudo privileges are required to run the install script!"
        exit 1
    fi
    
    declare_variables

    echo "########################"
    echo " # YAMS image creator #"
    echo "########################"


    ${sudo_prefix} apt update && ${sudo_prefix} apt upgrade -y
    ${sudo_prefix} apt install git kpartx fdisk
    ${sudo_prefix} apt install python make bison gettext binutils flex libglib2.0-dev libdevmapper1.02.1 unifont autoconf automake autopoint ttf-unifont gcc-arm-linux-gnueabihf gcc-aarch64-linux-gnu
    ${sudo_prefix} apt install gnu-efi help2man sbsigntool libfile-slurp-perl libssl-dev


    clone_repo & show_loading "Cloning all repositories"
    if [ $? -ne 0 ]; then
        error "Failed to clone repositories!"
    fi

    create_image & show_loading "Creating ${image_size} image file"
    if [ $? -ne 0 ]; then
        error "Failed to create image!"
    fi

    make_parition & show_loading 1> /dev/null "Making partitions"
    if [ $? -ne 0 ]; then
        error "Failed to make partitions!"
    fi
    mp=$(make_parition)
    if [ -z "$mp" ]; then
        echo $mp
    fi

    map_device 1> /dev/null & show_loading "Mapping device"
    if [ $? -ne 0 ]; then
        error "Failed to mapping device!"
    fi
    parts=$(map_device)
    SAVEIFS=$IFS
    IFS=$'\n'
    parts=($parts)
    IFS=$SAVEIFS
    image_loop=${parts[0]::-2}
    for i in "${parts[@]}";
    do
        echo -e "${colour_cyan}INFO: /dev/mapper/$i added!"
    done

    unmap_device & show_loading "Unmapping device"
    if [ $? -ne 0 ]; then
        error "Failed to unmapping device!"
    fi
    ud=$(unmap_device)
    if [ -z "$ud" ]; then
        echo $ud
    fi

    add_loop_device & show_loading "Adding loop device"
    if [ $? -ne 0 ]; then
        error "Failed to add loop device!"
    fi

    give_parition_filesystem > /dev/null 2>&1 & show_loading "Giving partitions filesystems"
    if [ $? -ne 0 ]; then
        error "Failed to give partitions filesystems!"
    fi
    gpf=$(give_parition_filesystem)
    if [ -z "$gpf" ]; then
        echo $gpf
    fi

    mount_filesystem "$mountpoint_ntfs" "${parts[0]}" & show_loading "Mounting NTFS partition to filesystem"
    if [ $? -ne 0 ]; then
        error "Failed to mount NTFS partition!"
    fi
	
    mount_filesystem "$mountpoint_fat32" "${parts[1]}" & show_loading "Mounting FAT32 partition to filesystem"
    if [ $? -ne 0 ]; then
        error "Failed to mount FAT32 partition!"
    fi

    setup_grub2 & show_loading "Setting up GRUB 2"
    if [ $? -ne 0 ]; then
        error "Failed to setup GRUB 2!"
    fi

    # i386-pc
    compile_grub2_i386-pc & show_loading "Compiling GRUB 2 (i386-pc)"
    if [ $? -ne 0 ]; then
       error "Failed to compile GRUB 2 (i386-pc)!"
    fi

    install_grub2_i386-pc & show_loading "Installing GRUB 2 (i386-pc)"
    if [ $? -ne 0 ]; then
       error "Failed to install GRUB 2 (i386-pc)!"
    fi
	
    # i386-efi
    compile_grub2_i386-efi & show_loading "Compiling GRUB 2 (i386-efi)"
    if [ $? -ne 0 ]; then
       error "Failed to compile GRUB 2 (i386-efi)!"
    fi

    install_grub2_i386-efi & show_loading "Installing GRUB 2 (i386-efi)"
    if [ $? -ne 0 ]; then
       error "Failed to install GRUB 2 (i386-efi)!"
    fi

    # x86_64-efi
    compile_grub2_x86_64-efi & show_loading "Compiling GRUB 2 (x86_64-efi)"
    if [ $? -ne 0 ]; then
        error "Failed to compile GRUB 2 (x86_64-efi)!"
    fi

    install_grub2_x86_64-efi & show_loading "Installing GRUB 2 (x86_64-efi)"
    if [ $? -ne 0 ]; then
        error "Failed to install GRUB 2 (x86_64-efi)!"
    fi
	
    # arm-efi
    compile_grub2_arm-efi & show_loading "Compiling GRUB 2 (arm-efi)"
    if [ $? -ne 0 ]; then
       error "Failed to compile GRUB 2 (arm-efi)!"
    fi

    install_grub2_arm-efi & show_loading "Installing GRUB 2 (arm-efi)"
    if [ $? -ne 0 ]; then
       error "Failed to install GRUB 2 (arm-efi)!"
    fi

    # arm64-efi
    compile_grub2_arm64-efi & show_loading "Compiling GRUB 2 (arm64-efi)"
    if [ $? -ne 0 ]; then
        error "Failed to compile GRUB 2 (arm64-efi)!"
    fi

    install_grub2_arm64-efi & show_loading "Installing GRUB 2 (arm64-efi)"
    if [ $? -ne 0 ]; then
        error "Failed to install GRUB 2 (arm64-efi)!"
    fi
	
	# Unmount
    unmount_filesystem "${parts[0]}" & show_loading "Unmounting NTFS partition"
    if [ $? -ne 0 ]; then
        error "Failed to unmount NTFS partition!"
    fi

    unmount_filesystem "${parts[1]}" & show_loading "Unmounting FAT32 partition"
    if [ $? -ne 0 ]; then
        error "Failed to unmount FAT32 partition!"
    fi

    unmap_device & show_loading "Unmapping device"
    if [ $? -ne 0 ]; then
        error "Failed to unmapping device!"
    fi
    ud=$(unmap_device)
    if [ -z "$ud" ]; then
        echo $ud
    fi

    echo "###############################"
    echo " # YAMS image created, DONE! # "
    echo "###############################"

    exit 0
}

main



