output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "mongodb_uri" {
  value = module.replicaset.mongo_uri
}

output "mongodb_public_ip" {
  value = module.replicaset.mongodb_public_ip
}

output "ssh_key_name" {
  value = module.network.ssh_key_name
}

output "mongodb_security_group_id" {
  value = module.replicaset.mongodb_security_group_id
}