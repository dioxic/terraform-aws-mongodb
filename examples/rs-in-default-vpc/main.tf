data "aws_ami" "base" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

module "config" {
  source = "github.com/dioxic/terraform-aws-mongodb-config"

  sharded                       = true
  shard_count                   = 2
  member_count                  = 5
  config_member_count           = 3
  image_id                      = data.aws_ami.base.image_id
  instance_type                 = "t3.micro"
  name                          = var.name
}

module "replicaset" {
    source = "../../"
    mongodb_version               = var.mongodb_version
    create_zone                   = true
    domain_name                   = var.domain_name
    subnet_ids                    = data.aws_subnet_ids.default.ids
    vpc_id                        = data.aws_vpc.default.id
    cluster_name                  = var.name
    ssh_key_name                  = var.ssh_key_name
    tags                          = var.tags
    router_nodes                  = module.config.router_nodes
    replica_sets                  = module.config.replica_sets
}