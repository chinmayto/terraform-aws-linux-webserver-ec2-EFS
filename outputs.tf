output "public_subnets" {
  value = module.vpc.public_subnets
}

output "security_groups_ec2" {
  value = module.vpc.security_group_ec2
}

output "ec2_instance_ids" {
  value = module.web.instance_ids
}

output "ec2_public_ips" {
  value = module.web.public_ip
}

output "efs_system-id"{
  value = aws_efs_file_system.efs_file_system.id
}