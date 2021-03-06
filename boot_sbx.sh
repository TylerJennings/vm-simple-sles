#!/bin/bash

#stop services
sudo rccron stop
sudo systemctl stop waagent

cp -f /etc/waagent.conf /etc/waagent.conf.orig
sedcmd="s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g"
sedcmd2="s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g"
sedcmd3="s/Provisioning.DecodeCustomData=n/Provisioning.DecodeCustomData=y/g"
sedcmd4="s/Provisioning.ExecuteCustomData=n/Provisioning.ExecuteCustomData=y/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf


echo "logicalvols start" > /usr/local/buildscript/parameter.txt
  bootdisk="$(df | grep boot | cut -c6,7,8)"
  number="$(lsscsi [*] 0 0 0| grep -v sr0| grep -v $bootdisk| cut -c2)"
  vg_system="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$' | cut -c 1-8)"
# parted to create 2 128gb partitions

parted -s $vg_system mklabel gpt mkpart primary 0GB 128GB
parted -s $vg_system mkpart primary 129GB 257GB

# pvcreate on both new paritions


  # vg_infraagentlun="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  # pvcreate $vg_infraagentlun
  pvcreate $vg_system'1'
  pvcreate $vg_system'2'
  # vgcreate vg_infraagent $vg_infraagentlun
  vgcreate vg_system $vg_system'1'
  vgcreate vg_infraagent $vg_system'2'
  lvcreate -L 4G -n lv_var vg_system
  lvcreate -L 4G -n lv_home vg_system
  lvcreate -L 8G -n lv_tmp vg_system
  lvcreate -L 4G -n lv_opt vg_system
  mkfs.ext4 /dev/vg_system/lv_var
  mkfs.ext4 /dev/vg_system/lv_home
  mkfs.ext4 /dev/vg_system/lv_tmp
  mkfs.ext4 /dev/vg_system/lv_opt

echo "logicalvols end" >> /usr/local/buildscript/parameter.txt


echo "mounthanashared start" >> /usr/local/buildscript/parameter.txt

mv /var /var.new
mv /home /home.new
mv /tmp /tmp.new
mv /opt /opt.new

mkdir /var
mkdir /home
mkdir /tmp
mkdir /opt

mount -t ext4 /dev/vg_system/lv_var /var
mount -t ext4 /dev/vg_system/lv_home /home
mount -t ext4 /dev/vg_system/lv_tmp /tmp
mount -t ext4 /dev/vg_system/lv_opt /opt

sleep 5

echo "mounthanashared end" >> /usr/local/buildscript/parameter.txt
#
#data moves
mv /var.new/* /var
mv /var.new/.* /var
mv /home.new/* /home
mv /home.new.* /home
mv /tmp.new/* /tmp
mv /tmp.new/.* /tmp
mv /opt.new/* /opt
mv /opt.new/.* /opt
rmdir /var.new
rmdir /home.new
rmdir /tmp.new
rmdir /opt.new
chmod 1777 /tmp


echo "write to fstab start" >> /tmp/parameter.txt
uuid1="$(blkid | grep lv_var | sed -e s/UUID=\"// | awk -F\" '{print $1}' | cut -d " " -f2)" 
uuid2="$(blkid | grep lv_home | sed -e s/UUID=\"// | awk -F\" '{print $1}' | cut -d " " -f2)"
uuid3="$(blkid | grep lv_tmp | sed -e s/UUID=\"// | awk -F\" '{print $1}' | cut -d " " -f2)"
uuid4="$(blkid | grep lv_opt | sed -e s/UUID=\"// | awk -F\" '{print $1}' | cut -d " " -f2)"
echo "UUID=$uuid1 /var ext4 nobarrier,nofail 0 0" >> /etc/fstab
echo "UUID=$uuid2 /home ext4 nobarrier,nofail 0 0" >> /etc/fstab
echo "UUID=$uuid3 /tmp ext4 nobarrier,nofail 0 0" >> /etc/fstab
echo "UUID=$uuid4 /opt ext4 nobarrier,nofail 0 0" >> /etc/fstab
echo "write to fstab end" >> /tmp/parameter.txt

echo "final reboot to reenable boot.ini and services"


mv /etc/rc.d/boot.local.orig /etc/rc.d/boot.local

touch /tmp/lastfile_before_logon
