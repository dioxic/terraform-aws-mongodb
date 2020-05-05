
module "config" {
  source = "github.com/dioxic/terraform-aws-mongodb-config"

  sharded                       = true
  shard_count                   = 1
  member_count                  = 3
  domain_name                   = var.domain_name
  image_id                      = "ami-06ce3edf0cff21f07"
  instance_type                 = "t3.micro"
  name                          = var.name
}

module "replicaset" {
    source = "../../"
    create                        = false
    domain_name                   = var.domain_name
    mongodb_version               = var.mongodb_version
    subnet_ids                    = ["subnet-1a", "subnet-2b", "subnet-3c"]
    vpc_id                        = "vpc-12345678"
    name                          = var.name
    ssh_key_name                  = "mykey"
    router_nodes                  = module.config.router_nodes
    config_replica_set            = module.config.config_replica_set
    data_replica_sets             = module.config.data_replica_sets
}

resource "local_file" "foo" {
  for_each    = module.replicaset.cloudinit_config

  content     = each.value.rendered
  filename = "${path.module}/out/${each.key}.cfg"
}