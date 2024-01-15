# Web Tier using AWS EC2 Linux - Multi-AZ with attached EFS

Deploying Linux Server EC2 Instances in AWS using Terraform with attached EFS File System

![Alt text](/images/diagram.png)

1. vpc module - to create vpc, public subnets, internet gateway, security groups and route tables
2. web module - to create Linux Web EC2 instances with userdata script to display instance metadata using latest Amazon Linux ami in multiple subnets created in vpc module
3. main module - Above modules get called in main config. And also creation of EFS along with mount mount targets

## Following are the steps we will follow to achieve our goal:
1. Create an AWS VPC with two public subnets on two different AZs.

2. Create two Security Groups. one is for EC2 instances which will allow inbound SSH traffic on port 22, and another one is for EFS mount targets which will allow inbound traffic on port 2049 only from the EC2 instances security group. And both security groups will allow outbound traffic to any port from anywhere.

3. Create an EFS file system.

4. Configure EFS mount targets along with the security group created for EFS mount targets.

5. Generate a custom script that will help us mount EFS on EC2 instances.

6. Deploy two EC2 instances on different subnets created on different AZs. While providing the EC2 instances execute the custom script we created for mounting EFS using terraform remote-exec provisioners.

## Test
To test whether the EFS file system is mounted on or not. SSH into the instances and run df -k command to find out all the mounted file systems on your EC2 instances.

## Side Notes
1. If you are using wsl on windows and vscode to create the bash script using local-exec, you need to save template file with EOL conversion to Unix (Use Edit->EOL Conversion in Notepad ++)
2. If you have installed docker-desktop, it creates its own distro, change it as follows so that wsl works as expected
```
> wsl -l
Windows Subsystem for Linux Distributions:
docker-desktop-data (Default)
docker-desktop

> wsl -s docker-desktop

> wsl -l
Windows Subsystem for Linux Distributions:
docker-desktop (Default)
docker-desktop-data
```
3. Generally it is advised not to use null_resources, but this exercise is just to explain the main concept of EFS.

4. EFS automount can fail for various reasons. /etc/fstab entry also may not work sometimes, refer this link to troubleshoot:

https://docs.aws.amazon.com/efs/latest/ug/troubleshooting-efs-mounting.html#automount-fails

## Bash Script used to mount file system:
```
#! /bin/bash
# Update the system packages
sudo yum update -y

# Create a directory for the content
sudo mkdir -p content/test/

# Install the Amazon EFS utilities
sudo yum -y install amazon-efs-utils

# Add an entry to /etc/fstab to mount the EFS file system
sudo su -c  "echo 'fs-0c4c5164674de43ca:/ content/test/ efs _netdev,tls 0 0' >> /etc/fstab"

# Mount the EFS file system
sudo mount content/test/

# Display the disk space usage
df -k
```


Terraform Plan Output:
```
Plan: 18 to add, 0 to change, 0 to destroy.
```

Terraform Apply Output:
```
null_resource.execute_script[0] (remote-exec): Filesystem            1K-blocks    Used        Available Use% Mounted on
null_resource.execute_script[0] (remote-exec): devtmpfs                 488756       0           488756   0% /dev
null_resource.execute_script[0] (remote-exec): tmpfs                    496748       0           496748   0% /dev/shm
null_resource.execute_script[0] (remote-exec): tmpfs                    496748     508           496240   1% /run
null_resource.execute_script[0] (remote-exec): tmpfs                    496748       0           496748   0% /sys/fs/cgroup
null_resource.execute_script[0] (remote-exec): /dev/xvda1              8376300 1613400          6762900  20% /
null_resource.execute_script[0] (remote-exec): tmpfs                     99352       0            99352   0% /run/user/1000
null_resource.execute_script[0] (remote-exec): 127.0.0.1:/    9007199254739968       0 9007199254739968   0% /home/ec2-user/content/test
null_resource.execute_script[1] (remote-exec): Filesystem            1K-blocks    Used        Available Use% Mounted on
null_resource.execute_script[1] (remote-exec): devtmpfs                 488756       0           488756   0% /dev
null_resource.execute_script[1] (remote-exec): tmpfs                    496748       0           496748   0% /dev/shm
null_resource.execute_script[1] (remote-exec): tmpfs                    496748     512           496236   1% /run
null_resource.execute_script[1] (remote-exec): tmpfs                    496748       0           496748   0% /sys/fs/cgroup
null_resource.execute_script[1] (remote-exec): /dev/xvda1              8376300 1613396          6762904  20% /
null_resource.execute_script[1] (remote-exec): tmpfs                     99352       0            99352   0% /run/user/1000
null_resource.execute_script[1] (remote-exec): 127.0.0.1:/    9007199254739968       0 9007199254739968   0% /home/ec2-user/content/test
null_resource.execute_script[0]: Creation complete after 2m15s [id=6876713525896539269]
null_resource.execute_script[1]: Creation complete after 2m16s [id=4318800104925290772]

Apply complete! Resources: 18 added, 0 changed, 0 destroyed.

Outputs:

ec2_instance_ids = [
  "i-009d9725d44b9a4af",
  "i-0cbafebadc3e979ab",
]
ec2_public_ips = [
  "18.207.209.158",
  "3.92.84.59",
]
efs_system-id = "fs-0a6a8d2a0bf361e82"
public_subnets = [
  "subnet-062ade0c005387293",
  "subnet-0b4cf5323555d73bb",
]
security_groups_ec2 = [
  "sg-00d94c603f9f4cae2",
]
```

Describe mounts output:

```
> aws efs describe-mount-targets --file-system-id fs-0a6a8d2a0bf361e82
{
    "MountTargets": [
        {
            "OwnerId": "197317184204",
            "MountTargetId": "fsmt-0cac4484d979db346",
            "FileSystemId": "fs-0a6a8d2a0bf361e82",
            "SubnetId": "subnet-0b4cf5323555d73bb",
            "IpAddress": "10.0.102.106",
            "NetworkInterfaceId": "eni-025da496afbe89878",
            "AvailabilityZoneId": "use1-az4",
            "AvailabilityZoneName": "us-east-1b",
            "VpcId": "vpc-07215ae183a672b93"
        },
        {
            "OwnerId": "197317184204",
            "MountTargetId": "fsmt-04a46d2b28e0ecb74",
            "FileSystemId": "fs-0a6a8d2a0bf361e82",
            "SubnetId": "subnet-062ade0c005387293",
            "LifeCycleState": "available",
            "IpAddress": "10.0.101.107",
            "NetworkInterfaceId": "eni-0e11e0a68b769d71d",
            "AvailabilityZoneId": "use1-az2",
            "AvailabilityZoneName": "us-east-1a",
            "VpcId": "vpc-07215ae183a672b93"
        }
    ]
}
```

Running Website:

![Alt text](/images/vm1.png)

![Alt text](/images/vm2.png)

EFS:
![Alt text](/images/efs.png)

![Alt text](/images/vm1mounts.png)

![Alt text](/images/vm2mounts.png)

Terraform Destroy Output:
```
Plan: 0 to add, 0 to change, 18 to destroy.

Destroy complete! Resources: 18 destroyed.
```