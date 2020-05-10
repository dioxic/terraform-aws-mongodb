
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

module "network" {
  source = "github.com/dioxic/terraform-aws-network"

  create_zone            = true
  bastion_count          = 1
  single_nat_gateway     = true
  enable_nat_gateway     = true
  name                   = var.name
  ssh_key_name           = var.ssh_key_name
  mongodb_version        = var.mongodb_version
  bastion_image_id       = data.aws_ami.base.id
  vpc_cidr               = "10.0.0.0/16"
  domain_name            = var.domain_name
  tags                   = var.tags
}

module "config" {
  source = "github.com/dioxic/terraform-aws-mongodb-config"

  sharded             = false
  member_count        = 3
  image_id            = data.aws_ami.base.image_id
  instance_type       = "t3.micro"
  name                = var.name
}

module "replicaset" {
  source = "../../"

  mongodb_version                       = var.mongodb_version
  create_zone                           = false
  create_zone_records                   = true
  zone_id                               = module.network.zone_id
  domain_name                           = var.domain_name
  subnet_ids                            = module.network.public_subnets
  vpc_id                                = module.network.vpc_id
  cluster_name                          = var.name
  ssh_key_name                          = var.ssh_key_name
  tags                                  = var.tags
  router_nodes                          = module.config.router_nodes
  replica_sets                          = module.config.replica_sets
  mongo_ingress_with_security_group_ids = [ module.network.bastion_security_group_id ]
}