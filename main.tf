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
        mongod_port = var.sharded ? var.sharded_mongod_port : var.mongod_port
        mongos_port = var.sharded && var.cohost_mongos ? var.mongos_port : null
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
        mongod_port    = var.config_mongod_port
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
          host = format("%s:%d", o.hostname, o.mongod_port)
        } if o.rs == rs  
      ]
    })
  }

  bastion_ingress_rules = distinct(concat(
    [ for o in local.shards : {
        from_port                = lookup(o, "mongod_port")
        to_port                  = lookup(o, "mongod_port")
        protocol                 = "tcp"
        description              = "MongoDB shard server port"
        source_security_group_id = var.vpc_ssh_security_group_id
      } if var.sharded
    ],
    [ for o in local.csrs : {
        from_port                = lookup(o, "mongod_port")
        to_port                  = lookup(o, "mongod_port")
        protocol                 = "tcp"
        description              = "MongoDB config server port"
        source_security_group_id = var.vpc_ssh_security_group_id
      }
    ],
    [
      {
        rule                     = "ssh-tcp"
        source_security_group_id = var.vpc_ssh_security_group_id
      }
    ]
  ))

  mongodb_internal_ingess = distinct(concat(
    [ for o in local.shards : {
        port        = lookup(o, "mongod_port")
        description = "MongoDB shard server"
      } if var.sharded
    ],
    [ for o in local.csrs : {
        port        = lookup(o, "mongod_port")
        description = "MongoDB config server port"
      }
    ]
  ))

  mongodb_external_ingess = distinct(concat(
    [ for o in local.shards : {
        port        = lookup(o, "mongod_port")
        description = "MongoDB replicaset port"
      } if !var.sharded
    ],
    [ for o in local.shards : {
        port        = lookup(o, "mongos_port")
        description = "MongoDB router port"
      } if lookup(o, "mongos_port") != null
    ]
  ))

}

resource "aws_security_group" "mongodb" {
  name        = format("%s-%s", var.name, "mongodb")
  vpc_id      = var.vpc_id
  description = "MongoDB hosts security group"
}

resource "aws_security_group_rule" "ssh_rule" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  description              = "SSH from Bastion"
  security_group_id        = aws_security_group.mongodb.id
  source_security_group_id = var.vpc_ssh_security_group_id
}

resource "aws_security_group_rule" "internal" {
  for_each = { for o in local.mongodb_internal_ingess : o.description => o }

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  description              = each.value.description
  security_group_id        = aws_security_group.mongodb.id
  self                     = true
}

resource "aws_security_group_rule" "external" {
  for_each = { for o in local.mongodb_external_ingess : o.description => o }

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  description              = each.value.description
  security_group_id        = aws_security_group.mongodb.id
  cidr_blocks              = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mongodb.id
}


# module "mongodb_sg" {
#   source  = "terraform-aws-modules/security-group/aws"
#   version = "~> 3.0"

#   name        = format("%s-%s", var.name, "mongodb")
#   vpc_id      = var.vpc_id

#   egress_rules        = ["all-all"]

#   ingress_with_cidr_blocks = distinct(concat(
#     [ for o in local.shards : {
#         from_port   = lookup(o, "mongod_port")
#         to_port     = lookup(o, "mongod_port")
#         protocol    = "tcp"
#         description = "MongoDB replicaset port"
#         cidr_blocks = "0.0.0.0/0"
#       } if !var.sharded
#     ],
#     [ for o in local.shards : {
#         from_port   = lookup(o, "mongos_port")
#         to_port     = lookup(o, "mongos_port")
#         protocol    = "tcp"
#         description = "MongoDB router port"
#         cidr_blocks = "0.0.0.0/0"
#       } if lookup(o, "mongos_port") != null
#     ]
#   ))

#   ingress_with_source_security_group_id = local.bastion_ingress_rules

#   ingress_with_self = distinct(concat(
#     [ for o in local.shards : {
#         from_port                = lookup(o, "mongod_port")
#         to_port                  = lookup(o, "mongod_port")
#         protocol                 = "tcp"
#         description              = "MongoDB shard server port"
#         self                     = true
#       } if var.sharded
#     ],
#     [ for o in local.csrs : {
#         from_port                = lookup(o, "mongod_port")
#         to_port                  = lookup(o, "mongod_port")
#         protocol                 = "tcp"
#         description              = "MongoDB config server port"
#         self                     = true
#       }
#     ]
#   ))

#   tags = var.tags
# }

resource "aws_instance" "mongodb" {
  for_each = local.nodes

  ami                    = each.value.isConfigServer ? var.csrs_ami : var.shard_ami
  instance_type          = each.value.isConfigServer ? var.csrs_instance_type : var.shard_instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.mongodb.id]
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
${templatefile("${path.module}/templates/common.sh.tpl", {})}
${templatefile("${path.module}/templates/set-hostname.sh.tpl", {
	  hostname = each.value.hostname
  }
)}
${templatefile("${path.module}/templates/install-repo.sh.tpl", {
    mongodb_version   = var.mongodb_version
    mongodb_community = var.mongodb_community
  }
)}
${templatefile("${path.module}/templates/install-packages.sh.tpl", {
    mongodb_community = var.mongodb_community
  }
)}
${templatefile("${path.module}/templates/configure-mongod.sh.tpl", {
    mongod_conf       = templatefile("${path.module}/templates/mongod.conf.tpl", {
      replSetName = each.value.rs
      clusterRole = each.value.isConfigServer ? "configsvr" : var.sharded ? "shardsvr" : ""
      hostname    = each.value.hostname
      port        = each.value.mongod_port
      mongod_conf = var.mongod_conf
    })
  }
)}
${each.value.member == 0 ? templatefile("${path.module}/templates/initiate-replicaset.sh.tpl", {
    rs_config = local.replica_cfg[each.value.rs]
    port      = each.value.mongod_port
  }
) : "" }
${contains(keys(each.value), "mongos_port") ? templatefile("${path.module}/templates/configure-mongos.sh.tpl", {
    mongos_conf              = templatefile("${path.module}/templates/mongos.conf.tpl", {
      configReplSetName = local.csrs[0].rs
      configServerHosts = join(",",[ for o in local.csrs : format("%s:%d", lookup(o, "hostname"), lookup(o, "mongod_port")) ])
      hostname          = each.value.hostname
      port              = each.value.mongos_port
      mongos_conf       = var.mongos_conf
    })
    mongos_service           = templatefile("${path.module}/templates/mongos.service.tpl", {})
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