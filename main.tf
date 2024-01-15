####################################################
# Create VPC and components
####################################################

module "vpc" {
  source                        = "./modules/vpc"
  aws_region                    = var.aws_region
  vpc_cidr_block                = var.vpc_cidr_block
  enable_dns_hostnames          = var.enable_dns_hostnames
  vpc_public_subnets_cidr_block = var.vpc_public_subnets_cidr_block
  aws_azs                       = var.aws_azs
  common_tags                   = local.common_tags
  naming_prefix                 = local.naming_prefix
}

####################################################
# Create Web Server Instances
####################################################

module "web" {
  source             = "./modules/web"
  instance_type      = var.instance_type
  instance_key       = var.instance_key
  common_tags        = local.common_tags
  naming_prefix      = local.naming_prefix
  public_subnets     = module.vpc.public_subnets
  security_group_ec2 = module.vpc.security_group_ec2
  depends_on = [
    null_resource.generate_efs_mount_script,
    aws_efs_mount_target.mount_targets
  ]
}

####################################################
# Create EFS and mount it at mountpoint on EC2
####################################################

####################################################
# Create the security group for EFS Mount Targets
####################################################
resource "aws_security_group" "aws-sg-efs" {
  description = "Security Group for EFS mount targets"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "EFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = tolist(module.vpc.security_group_ec2)
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = tolist(module.vpc.security_group_ec2)
  }

  tags = merge(local.common_tags, {
    Name = "${local.naming_prefix}-sg-efs"
  })
}

####################################################
# Create EFS
####################################################
resource "aws_efs_file_system" "efs_file_system" {
  creation_token   = "efs-test"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = merge(local.common_tags, {
    Name = "${local.naming_prefix}-efs"
  })
}

####################################################
# Create EFS mount targets
####################################################
resource "aws_efs_mount_target" "mount_targets" {
  count           = 2
  file_system_id  = aws_efs_file_system.efs_file_system.id
  subnet_id       = module.vpc.public_subnets[count.index]
  security_groups = [aws_security_group.aws-sg-efs.id]
}


####################################################
# Generate script for mounting EFS
####################################################
resource "null_resource" "generate_efs_mount_script" {

  provisioner "local-exec" {
    command = templatefile("efs_mount.tpl", {
      efs_mount_point = var.efs_mount_point
      file_system_id  = aws_efs_file_system.efs_file_system.id
    })
    interpreter = [
      "bash",
      "-c"
    ]
  }
}

####################################################
# Execute scripts on existing running EC2 instances
####################################################

resource "null_resource" "execute_script" {

  count = 2

  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = module.web.instance_ids[count.index]
  }

  provisioner "file" {
    source      = "efs_mount.sh"
    destination = "efs_mount.sh"
  }

  connection {
    host = module.web.public_ip[count.index]
    type = "ssh"
    user = "ec2-user"
    ## private_key = file(var.private_key_location) # Location of the Private Key
    private_key = file("D:/AWS/WorkshopKeyPair")
    timeout     = "4m"
  }

  provisioner "remote-exec" {
    # Bootstrap script called for each node in the cluster
    inline = [
      "bash efs_mount.sh",
    ]
  }
}

####################################################
# Cleanup existing script
####################################################
resource "null_resource" "clean_up" {

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf efs_mount.sh"

    interpreter = [
      "bash",
      "-c"
    ]
  }
}

