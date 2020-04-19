output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "bastion_security_group_id" {
  value = module.network.bastion_security_group_id
}

output "bastion_public_ip" {
  value = module.network.bastion_public_ip
}

output "mongodb_hostnames" {
  value = module.sharded_cluster.mongodb_hostnames
}

output "mongodb_security_group_id" {
  value = module.sharded_cluster.mongodb_security_group_id
}

output "ssh_key_name" {
  value = module.network.ssh_key_name
}