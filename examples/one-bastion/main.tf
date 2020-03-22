terraform {
  required_version = ">= 0.12.20"
}

data "aws_ami" "base" {
  most_recent = true

  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [
      "amzn2-ami-hvm-*-x86_64-gp2"
    ]
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
  bastion_count     = 1
  name              = "markbm-tf"
  ssh_key_name      = "markbm"
  mongodb_version   = "4.0"
  vpc_cidrs_private = ["10.1.14.0/24", "10.1.15.0/24", "10.1.16.0/24",]
  vpc_cidrs_public  = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24",]
  vpc_cidr          = "10.1.0.0/16"
  tags = {
    owner="mark.baker-munton"
  }
}