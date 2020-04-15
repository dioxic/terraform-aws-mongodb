output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "bastion_security_group" {
  value = module.network.bastion_security_group
}

output "bastion_public_ip" {
  value = module.network.bastion_public_ip
}

output "mongo_private_ip" {
  value = module.replicaset.mongodb_private_ip
}

output "private_key_name" {
  value = module.network.private_key_name
}

output "private_key_filename" {
  value = module.network.private_key_filename
}

output "private_key_pem" {
  value = module.network.private_key_pem
}

output "public_key_pem" {
  value = module.network.public_key_pem
}

output "public_key_openssh" {
  value = module.network.public_key_openssh
}

output "ssh_key_name" {
  value = module.network.ssh_key_name
}