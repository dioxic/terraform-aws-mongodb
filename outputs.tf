output "vpc_id" {
  value = var.vpc_id
}

output "mongodb_security_group_ids" {
  value = aws_security_group.mongodb[*].id
}

output "mongodb_public_ip" {
  value = [for v in aws_instance.mongodb: v.public_ip]
}

output "mongodb_private_ip" {
  value = [for v in aws_instance.mongodb: v.private_ip]
}

output "mongodb_hostnames" {
  value = [for o in local.nodes: o.fqdn]
}

output "nodes" {
  value = local.nodes
}

output "replica_sets" {
  value = local.replica_sets
}

output "mongo_uri" {
  value = coalesce(local.mongo_cluster_uri, try(local.mongo_rs_uri[0], null))
}

output "mongo_rs_uri" {
  value = local.mongo_rs_uri
}

output "user_data" {
  value = local.user_data
}

output "sharded" {
  value = local.sharded
}

output "router_uri" {
  value = local.router_uri
}

output "mongodb_internal_ingess" {
  value = local.mongodb_internal_ingess
}

output "mongodb_external_ingess" {
  value = local.mongodb_external_ingess
}

output "cloudinit_config" {
  value = data.template_cloudinit_config.config
}