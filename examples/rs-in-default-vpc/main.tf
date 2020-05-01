data "aws_ami" "base" {
  most_recent = true
  owners      = ["${var.ami_owner}"]

  filter {
    name   = "name"
    values = ["${var.ami_name}"]
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

data "aws_subnet_ids" "main" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_route53_zone" "main" {
  name = var.domain_name

  vpc {
    vpc_id = data.aws_vpc.default.id
  }

  tags = var.tags
}

module "replicaset" {
    source = "../../"

    zone_domain                   = var.domain_name
    mongodb_version               = var.mongodb_version
    sharded                       = false
    member_count                  = 3
    zone_id                       = aws_route53_zone.main.zone_id
    subnet_ids                    = data.aws_subnet_ids.main.ids
    vpc_id                        = data.aws_vpc.default.id
    image_id                      = data.aws_ami.base.id
    data_block_device_volume_size = 10
    name                          = var.name
    ssh_key_name                  = var.ssh_key_name
    tags                          = var.tags
}