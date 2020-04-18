terraform {
  required_version = ">= 0.12.20"
}

locals {
  shards        = flatten([
    for i in range(var.sharded ? var.shard_count : 1) : [
      for j in range(var.member_count) : {
        key         = format("%s-shard-%02d-%02d", var.name, i, j)
        rs          = format("%s-shard-%02d", var.name, i)
        member      = j
        shard       = i
        hostname    = format("%s-shard-%02d-%02d.%s", var.name, i, j, var.domain_name)
        isConfigServer = false
      }
    ]
  ])
  
  csrs           = var.sharded ? [
    for j in range(var.member_count) : {
        key            = format("%s-config-00-%02d", var.name, j)
        rs             = format("%s-config-00", var.name)
        member         = j
        hostname       = format("%s-config-00-%02d.%s", var.name, j, var.domain_name)
        isConfigServer = true
      }
    ] : []
  
  nodes           = { for o in concat(local.shards,local.csrs) : o.key => o }
  primary_nodes   = [for o in local.nodes : o if o.member == 0]
  secondary_nodes = [for o in local.nodes : o if o.member != 0]
  replica_sets    = distinct([for o in local.nodes : lookup(o, "rs")])
  replica_cfg     = {
    for rs in local.replica_sets : rs => jsonencode({
      _id = rs
      members: [
        for o in local.nodes : {
          _id  = o.member
          host = o.hostname
        } if o.rs == rs  
      ]
    })
  }
}

module "mongodb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3.0"

  name        = format("%s-%s", var.name, "mongodb")
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp", "all-icmp", "mongodb-27017-tcp"]
  egress_rules        = ["all-all"]

  tags = var.tags
}

resource "aws_instance" "mongodb" {
  for_each = local.nodes

  ami                    = each.value.isConfigServer ? var.csrs_ami : var.shard_ami
  instance_type          = each.value.isConfigServer ? var.csrs_instance_type : var.shard_instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [module.mongodb_sg.this_security_group_id]
  subnet_id              = element(
    var.subnet_ids,
    each.value.member,
  )

  tags = merge(
    {
      "Name" = each.key
    },
    var.tags
  )

  user_data              = <<EOF
${templatefile("${path.module}/templates/set-hostname.sh.tpl", {
	  hostname = each.value.hostname
  }
)}
${templatefile("${path.module}/templates/install-repo.sh.tpl", {
    mongodb_version   = var.mongodb_version,
    mongodb_community = var.mongodb_community
  }
)}
${templatefile("${path.module}/templates/install-mongod.sh.tpl", {
    mongodb_community = var.mongodb_community
    mongod_conf       = templatefile("${path.module}/templates/mongod.conf.tpl", {
      replSetName = each.value.rs
      clusterRole = each.value.isConfigServer ? "configsvr" : var.sharded ? "shardsvr" : ""
      port        = var.mongod_port
      mongod_conf = var.mongod_conf
    })
  }
)}
${each.value.member == 0 ? templatefile("${path.module}/templates/initiate-replicaset.sh.tpl", {
    rs_config = local.replica_cfg[each.value.rs]
  }
) : "" }
EOF
}

resource "aws_route53_record" "mongodb" {
  for_each = local.nodes

  zone_id = var.zone_id
  name    = each.value.hostname
  type    = "A"
  ttl     = "300"
  records = [aws_instance.mongodb[each.key].private_ip]
}