terraform {
  required_version = ">= 0.12.20"
}

locals {
  data_block_device           = "/dev/${var.ebs_block_device_name}"
  db_path                     = "${var.ebs_block_device_mount_point}/db"
  mongo_uri                   = "mongodb+srv://${var.name}.${var.domain_name}/?ssl=${var.enable_ssl}&replicaSet=${var.name}"

  parsed_data_replica_set = [ for rs in var.data_replica_sets : merge({is_config_rs = false }, rs) ]
  parsed_config_replica_set = var.config_replica_set != null ? [merge({is_config_rs = true }, var.config_replica_set)] : []
  parsed_router_nodes = var.router_nodes != null ? var.router_nodes : []

  replica_sets   = { for rs in concat(local.parsed_config_replica_set, local.parsed_data_replica_set) : rs.name => merge(rs, {
    hosts     = [ for node in rs.nodes : format("%s:%d", node.hostname, node.mongod_port) ]
    hosts_csv = join(",", [for node in rs.nodes : format("%s:%d", node.hostname, node.mongod_port)])
    uri       = format("mongodb://%s/?ssl=%s&replicaSet=%s",
      join(",", [ for node in rs.nodes : format("%s:%d", node.hostname, node.mongod_port) ]),
      var.enable_ssl,
      rs.name
    )
    cfg = jsonencode({
      _id = rs.name
      members: [
      for o in rs.nodes : {
        _id = index(rs.nodes, o)
        host = format("%s:%d", o.hostname, o.mongod_port)
        votes = o.votes
        hidden = o.hidden
        priority = o.priority
        arbiterOnly = o.arbiter_only
      }]
    })
  })}

  csrs_replica_sets = [ for rs in local.replica_sets : rs if rs.is_config_rs ]
  csrs_replica_set  = length(local.csrs_replica_sets) > 0 ? local.csrs_replica_sets[0] : null

  default_node = {
    mongos_port = null,
    mongod_port = null
  }

  rs_nodes = flatten([ for rs in local.replica_sets : [
    for node in rs.nodes : merge({
      rs_name    = rs.name,
      shard_name = ""
      member     = index(rs.nodes, node)
    }, node)
  ]])

  nodes = { for node in concat(local.rs_nodes, local.parsed_router_nodes) : node.name => merge(local.default_node, node) }

  router_hosts     = [ for node in local.nodes : join(":", [node.hostname,node.mongos_port]) if node.mongos_port != null ]
  router_uri       = format("mongodb://%s", join(",",slice(local.router_hosts, 0, min(3, length(local.router_hosts)))))

  sharded          = length(local.router_hosts) > 0

  mongodb_internal_ingess = distinct(concat(
    [ for o in local.nodes : {
        port        = o.mongod_port
        description = local.replica_sets[o.rs_name].is_config_rs ? "MongoDB config server port" : "MongoDB shard server"
      } if o.mongod_port != null
    ],
    [ for o in local.nodes : {
        port        = o.mongos_port
        description = "MongoDB router port"
      } if o.mongos_port != null
    ]
  ))

  mongodb_external_ingess = distinct(concat(
    [ for o in local.nodes : {
        port        = o.mongod_port
        description = local.replica_sets[o.rs_name].is_config_rs ? "MongoDB config server port" : "MongoDB shard server"
      } if o.mongod_port != null
    ],
    [ for o in local.nodes : {
        port        = o.mongos_port
        description = "MongoDB router port"
      } if o.mongos_port != null
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
    each.value.member % length(var.subnet_ids),
  )

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  ebs_block_device {
    device_name = local.data_block_device
    volume_type = each.value.volume_type
    volume_size = each.value.volume_size
    iops        = each.value.volume_iops
  }  

  tags = merge(
    {
      "Name" = each.key
    },
    var.tags
  )

  user_data              = <<-EOF
${templatefile("${path.module}/templates/common.sh", {
    mongodb_version       = var.mongodb_version
    mongodb_community     = var.mongodb_community
    hostname              = each.value.hostname
    mongo_uri             = local.mongo_uri
})}
set_hostname
install_repo
install_packages
${each.value.mongod_port != null  ? templatefile("${path.module}/templates/configure-mongod.sh", {
    db_path               = local.db_path
    rs_name               = each.value.rs_name
    rs_config             = local.replica_sets[each.value.rs_name].cfg
    rs_hosts              = local.replica_sets[each.value.rs_name].hosts
    rs_hosts_csv          = local.replica_sets[each.value.rs_name].hosts_csv
    rs_uri                = local.replica_sets[each.value.rs_name].uri
    shard_name            = each.value.shard_name
    data_block_device     = local.data_block_device
    mount_point           = var.ebs_block_device_mount_point
    router_uri            = local.router_uri
    mongod_port           = each.value.mongod_port
    mongod_conf           = templatefile("${path.module}/templates/mongod.config", {
      replSetName = each.value.rs_name
      clusterRole = local.replica_sets[each.value.rs_name].is_config_rs ? "configsvr" : local.sharded ? "shardsvr" : ""
      hostname    = each.value.hostname
      port        = each.value.mongod_port
      mongod_conf = var.mongod_conf
      db_path     = local.db_path
    })
}) : ""}
${each.value.member == 0 ? "initiate_replica_set" : "" }
${each.value.mongos_port != null ? templatefile("${path.module}/templates/configure-mongos.sh", {
    mongos_service        = file("${path.module}/templates/mongos.service")

    mongos_conf           = templatefile("${path.module}/templates/mongos.config", {
      csrs_name         = local.csrs_replica_set.name
      csrs_hosts        = local.csrs_replica_set.hosts_csv
      hostname          = each.value.hostname
      port              = each.value.mongos_port
      mongos_conf       = var.mongos_conf
    })
}) : ""}
${each.value.member == 0 && !local.replica_sets[each.value.rs_name].is_config_rs ? "add_shard" : ""}
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
resource "aws_route53_record" "mongodb_srv_rs" {
  for_each = local.replica_sets

  zone_id = var.zone_id
  name    = "_mongodb._tcp.${each.value.name}"
  type    = "SRV"
  ttl     = "300"
  records = [ for o in each.value.nodes : "0 0 ${o.mongod_port} ${o.hostname}"]
}

//resource "aws_route53_record" "mongodb_txt_rs" {
//  for_each = local.replica_sets
//
//  zone_id = var.zone_id
//  name    = "_mongodb._tcp.${each.value.name}"
//  type    = "SRV"
//  ttl     = "300"
//  records = [ for o in each.value.nodes : "0 0 ${o.mongod_port} ${o.hostname}"]
//}

resource "aws_route53_record" "mongodb_srv_router" {
  count   = local.sharded ? 1 : 0

  zone_id = var.zone_id
  name    = "_mongodb._tcp.${var.name}"
  type    = "SRV"
  ttl     = "300"
  records = [ for node in local.nodes : "0 0 ${node.mongos_port} ${node.hostname}" if node.mongos_port != null ]
}