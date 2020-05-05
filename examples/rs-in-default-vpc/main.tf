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

resource "aws_route53_zone" "main" {
  name = var.domain_name

  vpc {
    vpc_id = data.aws_vpc.default.id
  }

  tags = var.tags
}

module "config" {
  source = "github.com/dioxic/terraform-aws-mongodb-config"

  sharded                       = true
  shard_count                   = 1
  member_count                  = 3
  domain_name                   = var.domain_name
  image_id                      = data.aws_ami.base.image_id
  instance_type                 = "t3.micro"
  name                          = var.name
}

module "replicaset" {
    source = "../../"
    domain_name                   = var.domain_name
    mongodb_version               = var.mongodb_version
    zone_id                       = aws_route53_zone.main.zone_id
    subnet_ids                    = data.aws_subnet_ids.default.ids
    vpc_id                        = data.aws_vpc.default.id
    name                          = var.name
    ssh_key_name                  = var.ssh_key_name
    tags                          = var.tags
    router_nodes                  = module.config.router_nodes
    config_replica_set            = module.config.config_replica_set
    data_replica_sets             = module.config.data_replica_sets
}