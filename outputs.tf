output "mongodb_security_group_id" {
  value = aws_security_group.mongodb.id
}

output "mongodb_public_ip" {
  value = [for v in aws_instance.mongodb: v.public_ip]
}

output "mongodb_private_ip" {
  value = [for v in aws_instance.mongodb: v.private_ip]
}

output "mongodb_hostnames" {
  value = [for o in local.nodes: o.hostname]
}

output "nodes" {
  value = local.nodes
}

output "replica_cfg" {
  value = local.replica_cfg
}

