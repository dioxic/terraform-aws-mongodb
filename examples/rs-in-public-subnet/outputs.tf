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
  value = module.replicaset.mongodb_hostnames
}

output "mongodb_public_ip" {
  value = module.replicaset.mongodb_public_ip
}

output "mongodb_security_group_id" {
  value = module.replicaset.mongodb_security_group_id
}

output "ssh_key_name" {
  value = module.network.ssh_key_name
}

# output "private_key_name" {
#   value = module.network.private_key_name
# }

# output "private_key_filename" {
#   value = module.network.private_key_filename
# }

# output "private_key_pem" {
#   value = module.network.private_key_pem
# }

# output "public_key_pem" {
#   value = module.network.public_key_pem
# }

# output "public_key_openssh" {
#   value = module.network.public_key_openssh
# }



# output "nodes" {
#   value = module.replicaset.nodes
# }
