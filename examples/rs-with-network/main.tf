locals {
    name              = "markbm-tf"
    ssh_key_name      = "markbm"    
    domain_name       = "example.com"
    mongodb_version   = "4.2"
    tags = {
        owner = "mark.baker-munton"
    }
}

module "network" {
    source = "github.com/dioxic/terraform-aws-network"

    create                 = true
    create_zone            = true
    bastion_count          = 1
    name                   = local.name
    ssh_key_name           = local.ssh_key_name
    mongodb_version        = local.mongodb_version
    vpc_cidrs_private      = ["10.0.1.0/24"]
    vpc_cidrs_public       = ["10.0.11.0/24"]
    vpc_cidr               = "10.0.0.0/16"
    domain_name            = local.domain_name
    tags                   = local.tags
}

module "replicaset" {
    source = "../../"

    domain_name          = local.domain_name
    mongodb_version      = local.mongodb_version
    replicaset           = true
    configServer         = true
    #member_count         = 3
    zone_id              = module.network.zone_id
    subnet_ids           = module.network.private_subnets
    vpc_id               = module.network.vpc_id
    name                 = local.name
    ssh_key_name         = local.ssh_key_name
    tags                 = local.tags
}