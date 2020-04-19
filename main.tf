terraform {
  required_version = ">= 0.12.20"
}

locals {
  config_server_image_id      = var.config_server_image_id != "" ? var.config_server_image_id : var.image_id
  config_server_instance_type = var.config_server_instance_type != "" ? var.config_server_instance_type : var.instance_type

  shards        = flatten([
    for i in range(var.sharded ? var.shard_count : 1) : [
      for j in range(var.member_count) : {
        key         = format("%s-shard-%02d-%02d", var.name, i, j)
        rs          = format("%s-shard-%02d", var.name, i)
        member      = j
        shard       = i
        mongod_port = var.sharded ? var.sharded_mongod_port : var.mongod_port
        mongos_port = var.sharded && var.cohost_mongos ? var.mongos_port : -1
        hostname    = format("%s-shard-%02d-%02d.%s", var.name, i, j, var.zone_domain)
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
        mongos_port    = -1
        hostname       = format("%s-config-00-%02d.%s", var.name, j, var.zone_domain)
        isConfigServer = true
      }
    ] : []
  
  nodes           = { for o in concat(local.shards,local.csrs) : o.key => o }
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
      } if lookup(o, "mongos_port") != -1
    ]
  ))

}

resource "aws_security_group" "mongodb" {
  name        = format("%s-%s", var.name, "mongodb")
  vpc_id      = var.vpc_id
  description = "MongoDB servers security group"
  tags        = merge(
    {
      "Name" = format("%s-%s", var.name, "mongodb")
    },
    var.tags
  )
}

resource "aws_security_group_rule" "ssh_bastion" {
  count = var.ssh_from_security_group_only ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  description              = "SSH from Bastion"
  security_group_id        = aws_security_group.mongodb.id
  source_security_group_id = var.vpc_ssh_security_group_id
}

resource "aws_security_group_rule" "ssh_anywhere" {
  count = !var.ssh_from_security_group_only ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  description              = "SSH from anywhere"
  security_group_id        = aws_security_group.mongodb.id
  cidr_blocks              = ["0.0.0.0/0"]
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

resource "aws_instance" "mongodb" {
  for_each = local.nodes

  ami                    = each.value.isConfigServer ? local.config_server_image_id : var.image_id
  instance_type          = each.value.isConfigServer ? local.config_server_instance_type : var.instance_type
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
${each.value.mongod_port != -1  ? templatefile("${path.module}/templates/configure-mongod.sh.tpl", {
    mongod_conf       = templatefile("${path.module}/templates/mongod.conf.tpl", {
      replSetName = each.value.rs
      clusterRole = each.value.isConfigServer ? "configsvr" : var.sharded ? "shardsvr" : ""
      hostname    = each.value.hostname
      port        = each.value.mongod_port
      mongod_conf = var.mongod_conf
    })
  }
) : ""}
${each.value.member == 0 ? templatefile("${path.module}/templates/initiate-replicaset.sh.tpl", {
    rs_config = local.replica_cfg[each.value.rs]
    port      = each.value.mongod_port
  }
) : "" }
${each.value.mongos_port != -1 ? templatefile("${path.module}/templates/configure-mongos.sh.tpl", {
    mongos_conf              = templatefile("${path.module}/templates/mongos.conf.tpl", {
      configReplSetName = local.csrs[0].rs
      configServerHosts = join(",",[ for o in local.csrs : format("%s:%d", lookup(o, "hostname"), lookup(o, "mongod_port")) ])
      hostname          = each.value.hostname
      port              = each.value.mongos_port
      mongos_conf       = var.mongos_conf
    })
    mongos_service           = file("${path.module}/templates/mongos.service.tpl")
  }
) : "" }
${each.value.member == 0 && var.sharded && !each.value.isConfigServer ? templatefile("${path.module}/templates/initiate-shard.sh.tpl", {
    shardReplSetName = each.value.rs
    shardHosts       = join(",",[ for o in local.shards : format("%s:%d", lookup(o, "hostname"), lookup(o, "mongod_port")) if lookup(o, "rs") == each.value.rs ])
    shardName        = format("shard%d", each.value.shard)
    mongos_port      = each.value.mongos_port
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