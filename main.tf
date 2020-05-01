terraform {
  required_version = ">= 0.12.20"
}

locals {
  data_block_device           = "/dev/${var.data_block_device_name}"
  db_path                     = "${var.data_mount_point}/db"
  mongo_uri                   = "mongodb+srv://${var.name}.${var.zone_domain}/?ssl=${var.enable_ssl}&replicaSet=${var.name}"

  shards        = flatten([
    for i in range(var.sharded ? var.shard_count : 1) : [
      for j in range(var.member_count) : {
        key            = format("%s-shard-%02d-%02d", var.name, i, j)
        rs             = format("%s-shard-%02d", var.name, i)
        member         = j
        shard          = i
        node           = j + (var.member_count * i )
        mongod_port    = var.sharded ? var.sharded_mongod_port : var.mongod_port
        mongos_port    = var.sharded && var.cohost_mongos && (j + (var.member_count * i ) < var.mongos_count) ? var.mongos_port : -1
        hostname       = format("%s-shard-%02d-%02d.%s", var.name, i, j, var.zone_domain)
        instance_type  = var.instance_type
        image_id       = var.image_id
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
        instance_type  = var.config_instance_type != "" ? var.config_instance_type : var.instance_type
        image_id       = var.config_image_id != "" ? var.config_image_id : var.image_id
        isConfigServer = true
      }
    ] : []

  routers          = var.sharded && !var.cohost_mongos ? [
    for i in range(var.mongos_count) : {
        key            = format("%s-router-00-%02d", var.name, i)
        mongos_port    = var.mongos_port
        hostname       = format("%s-router-00-%02d.%s", var.name, i, var.zone_domain)
        instance_type  = var.router_instance_type != "" ? var.router_instance_type : var.instance_type
        image_id       = var.router_image_id != "" ? var.router_image_id : var.image_id
        isConfigServer = false
    }
  ] : []

  nodes            = { for o in concat(local.shards,local.csrs,local.routers) : o.key => o }

  router_nodes     = [ for o in local.nodes : o if o.mongos_port != -1 ]
  router_hosts     = [ for o in local.nodes : join(":",o.hostname,o.mongos_port) if o.mongos_port != -1 ]
  router_uri       = format("mongodb://%s", join(",",slice(local.router_hosts, 0, min(3, length(local.router_hosts)))))

  replica_sets     = {
    for rs in distinct([for o in local.nodes : lookup(o, "rs")]) : rs => {
      hosts      = [ for o in local.nodes : format("%s:%d", o.hostname, o.mongod_port) if o.rs == rs ]
      hosts_csv  = join(",", [for o in local.nodes : format("%s:%d", o.hostname, o.mongod_port) if o.rs == rs])
      cfg        = jsonencode({
        _id = rs
        members: [
          for o in local.nodes : {
            _id      = o.member
            host     = format("%s:%d", o.hostname, o.mongod_port)
          } if o.rs == rs  
        ]
      })
    }
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

  ami                    = each.value.image_id
  instance_type          = each.value.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.mongodb.id]
  subnet_id              = element(
    var.subnet_ids,
    each.value.member,
  )

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  ebs_block_device {
    device_name = local.data_block_device
    volume_type = var.data_block_device_volume_type
    volume_size = var.data_block_device_volume_size
    iops        = var.data_block_device_iops
  }  

  tags = merge(
    {
      "Name" = each.key
    },
    var.tags
  )

  user_data              = <<EOF
${templatefile("${path.module}/templates/common.sh.tpl", {
    mongodb_version       = var.mongodb_version
    mongodb_community     = var.mongodb_community
	  hostname              = each.value.hostname
    mongo_uri             = local.mongo_uri
})}
set_hostname
install_repo
install_packages
${each.value.mongod_port != -1  ? templatefile("${path.module}/templates/configure-mongod.sh.tpl", {
    db_path               = local.db_path
    rs_name               = each.value.rs
    rs_config             = local.replica_sets[each.value.rs].cfg
    rs_hosts              = local.replica_sets[each.value.rs].hosts
    rs_hosts_csv          = local.replica_sets[each.value.rs].hosts_csv
    rs_uri                = "mongodb://${local.replica_sets[each.value.rs].hosts_csv}/?ssl=${var.enable_ssl}&replicaSet=${each.value.rs}"
    shard_name            = format("shard%d", each.value.shard)
    data_block_device     = local.data_block_device
    mount_point           = var.data_mount_point
    router_uri            = local.router_uri
    mongod_port           = each.value.mongod_port
    mongod_conf           = templatefile("${path.module}/templates/mongod.conf.tpl", {
      replSetName = each.value.rs
      clusterRole = each.value.isConfigServer ? "configsvr" : var.sharded ? "shardsvr" : ""
      hostname    = each.value.hostname
      port        = each.value.mongod_port
      mongod_conf = var.mongod_conf
      db_path     = local.db_path
    })
}) : ""}
${each.value.member == 0 ? "initiate_replica_set" : "" }
${each.value.mongos_port != -1 ? templatefile("${path.module}/templates/configure-mongos.sh.tpl", {
    mongos_service        = file("${path.module}/templates/mongos.service.tpl")

    mongos_conf           = templatefile("${path.module}/templates/mongos.conf.tpl", {
      csrs_name         = local.csrs[0].rs
      csrs_hosts        = join(",",[ for o in local.csrs : format("%s:%d", lookup(o, "hostname"), lookup(o, "mongod_port")) ])
      hostname          = each.value.hostname
      port              = each.value.mongos_port
      mongos_conf       = var.mongos_conf
    })
}) : ""}
${each.value.member == 0 && var.sharded && !each.value.isConfigServer ? "add_shard" : ""}
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

## only for RS currently - need to change for mongos SRV
resource "aws_route53_record" "mongodb_srv" {
  zone_id = var.zone_id
  name    = "_mongodb._tcp.${var.name}"
  type    = "SRV"
  ttl     = "300"
  records = [ for o in local.shards : "0 0 ${o.mongod_port} ${o.hostname}"]
}