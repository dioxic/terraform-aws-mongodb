
data "aws_ami" "base" {
  most_recent = true
  owners = [var.ami_owner]

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

module "network" {
  source = "github.com/dioxic/terraform-aws-network"

  create_zone            = true
  create_bastion         = false
  name                   = var.name
  create_private_subnets = false
  ssh_key_name           = var.ssh_key_name
  mongodb_version        = var.mongodb_version
  vpc_cidr               = "10.0.0.0/16"
  domain_name            = var.domain_name
  tags                   = var.tags
}

module "config" {
  source = "github.com/dioxic/terraform-aws-mongodb-config"

  sharded             = false
  shard_count         = 1
  member_count        = 3
  image_id            = data.aws_ami.base.image_id
  instance_type       = "t3.micro"
  name                = var.name
}

module "replicaset" {
  source = "../../"

  mongodb_version               = var.mongodb_version
  create_zone                   = false
  create_zone_records           = true
  zone_id                       = module.network.zone_id
  domain_name                   = var.domain_name
  subnet_ids                    = module.network.public_subnets
  vpc_id                        = module.network.vpc_id
  cluster_name                  = var.name
  ssh_key_name                  = var.ssh_key_name
  tags                          = var.tags
  router_nodes                  = module.config.router_nodes
  replica_sets                  = module.config.replica_sets
  ssh_ingress_with_cidr_blocks  = ["0.0.0.0/0"]
}