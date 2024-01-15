cat << EOF >> efs_mount.sh
#! /bin/bash
sudo mkdir -p ${efs_mount_point}
sudo su -c  "echo '${file_system_id}:/ ${efs_mount_point} efs _netdev,tls 0 0' >> /etc/fstab"
sleep 120
sudo mount ${efs_mount_point}
df -k

EOF