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

output "data_replica_sets" {
  value = module.config.data_replica_sets
}

output "replica_sets" {
  value = module.replicaset.replica_sets
}

output "mongo_uri" {
  value = module.replicaset.mongo_uri
}

//output "user_data" {
//  value = module.replicaset.user_data
//}

output "sharded" {
  value = module.replicaset.sharded
}

output "router_uri" {
  value = module.replicaset.router_uri
}

output "mongodb_internal_ingess" {
  value = module.replicaset.mongodb_internal_ingess
}

output "mongodb_external_ingess" {
  value = module.replicaset.mongodb_external_ingess
}

//output "cloudinit_config" {
//  value = module.replicaset.cloudinit_config
//}