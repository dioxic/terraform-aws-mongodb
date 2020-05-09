output "mongodb_uri" {
  value = module.replicaset.mongo_uri
}

output "mongodb_hostnames" {
  value = module.replicaset.mongodb_hostnames
}

output "mongodb_public_ip" {
  value = module.replicaset.mongodb_public_ip
}

output "nodes" {
  value = module.replicaset.nodes
}

output "replica_sets" {
  value = module.replicaset.replica_sets
}

output "mongo_uri" {
  value = module.replicaset.mongo_uri
}

output "mongo_rs_uri" {
  value = module.replicaset.mongo_rs_uri
}

output "sharded" {
  value = module.replicaset.sharded
}

output "security_group_ingress_rules" {
  value = module.replicaset.security_group_ingress_rules
}