output "mongodb_security_group" {
  value = module.mongodb_sg.this_security_group_id
}

output "mongodb_public_ip" {
  value = [for v in aws_instance.mongodb: v.public_ip]
}

output "mongodb_private_ip" {
  value = [for v in aws_instance.mongodb: v.private_ip]
}

output "nodes" {
  value = local.nodes
}

output "replica_cfg" {
  value = local.replica_cfg
}