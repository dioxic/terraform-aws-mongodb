
module "config" {
  source = "github.com/dioxic/terraform-aws-mongodb-config"

  sharded                       = true
  cohost_routers                = false
  shard_count                   = 1
  member_count                  = 5
  config_member_count           = 3
  router_count                  = 2
  image_id                      = "ami-06ce3edf0cff21f07"
  instance_type                 = "t3.micro"
  name                          = var.name
}

module "replicaset" {
  source = "../../"

  create                                = false
  domain_name                           = "example.internal"
  mongodb_version                       = var.mongodb_version
  subnet_ids                            = ["subnet-1a", "subnet-2b", "subnet-3c"]
  vpc_id                                = "vpc-12345678"
  cluster_name                          = var.name
  ssh_key_name                          = "mykey"
  router_nodes                          = module.config.router_nodes
  replica_sets                          = module.config.replica_sets
  ssh_ingress_with_cidr_blocks          = ["0.0.0.0/0"]
  mongo_ingress_with_security_group_ids = ["sg-1234"]
}

resource "local_file" "cloud-init" {
  for_each    = module.replicaset.cloudinit_config

  content     = each.value.rendered
  filename = "${path.module}/out/${each.key}_cloud-init.yml"
}

resource "local_file" "mongod-conf" {
  for_each    = module.replicaset.mongod_conf

  content     = each.value
  filename = "${path.module}/out/${each.key}_mongod.conf"
}

resource "local_file" "mongos-conf" {
  for_each    = module.replicaset.mongos_conf

  content     = each.value
  filename = "${path.module}/out/${each.key}_mongos.conf"
}