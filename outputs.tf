output "vpc_id" {
  value = var.vpc_id
}

output "mongodb_security_group_id" {
  value = local.security_group_id
}

output "mongodb_public_ip" {
  value = values(aws_instance.mongodb)[*].public_ip
}

output "mongodb_private_ip" {
  value = values(aws_instance.mongodb)[*].private_ip
}

output "mongodb_hostnames" {
  value = values(local.nodes)[*].fqdn
}

output "nodes" {
  value = local.nodes
}

output "replica_sets" {
  value = local.replica_sets
}

output "mongo_uri" {
  value = coalesce(local.mongo_cluster_uri, local.mongo_rs_uri[0])
}

output "mongo_rs_uri" {
  value = local.mongo_rs_uri
}

output "user_data" {
  value = local.user_data
}

output "mongod_conf" {
  value = local.mongod_conf
}

output "mongos_conf" {
  value = local.mongos_conf
}

output "domain_name" {
  value = local.domain_name
}

output "sharded" {
  value = local.sharded
}

output "security_group_ingress_rules" {
  value = concat(
    local.ssh_ingress_self,
    local.ssh_ingress_cidr,
    local.ssh_ingress_sg,
    local.mongo_ingress_self,
    local.mongo_ingress_cidr,
    local.mongo_ingress_sg
  )
}

output "cloudinit_config" {
  value = data.template_cloudinit_config.mongodb
}