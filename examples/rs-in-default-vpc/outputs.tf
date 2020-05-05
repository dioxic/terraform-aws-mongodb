output "vpc_cidr" {
  value = data.aws_vpc.default.cidr_block
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "mongodb_hostnames" {
  value = module.replicaset.mongodb_hostnames
}

output "mongodb_public_ip" {
  value = module.replicaset.mongodb_public_ip
}

output "mongodb_security_group_ids" {
  value = module.replicaset.mongodb_security_group_ids
}

output "ssh_key_name" {
  value = var.ssh_key_name
}

output "mongo_uri" {
  value = module.replicaset.mongo_uri
}

output "tags" {
  value = var.tags
}