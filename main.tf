terraform {
  required_version = ">= 0.12.20"
}

locals {
  bootstrap_path              = "/var/lib/cloud/scripts/bootstrap.sh"
  data_block_device           = "/dev/${var.ebs_block_device_name}"
  db_path                     = "${var.ebs_block_device_mount_point}/db"

  parsed_data_replica_set = [ for rs in var.data_replica_sets : merge({is_config_rs = false }, rs) ]
  parsed_config_replica_set = var.config_replica_set != null ? [merge({is_config_rs = true }, var.config_replica_set)] : []
  parsed_router_nodes = var.router_nodes != null ? var.router_nodes : []

  replica_sets   = { for rs in concat(local.parsed_config_replica_set, local.parsed_data_replica_set) : rs.name => merge(rs, {
    hosts     = [ for node in rs.nodes : format("%s:%d", node.fqdn, node.mongod_port) ]
    hosts_csv = join(",", [for node in rs.nodes : format("%s:%d", node.fqdn, node.mongod_port)])
    uri       = format("mongodb://%s/?ssl=%s&replicaSet=%s",
      join(",", [ for node in rs.nodes : format("%s:%d", node.fqdn, node.mongod_port) ]),
      var.enable_ssl,
      rs.name
    )
    cfg = jsonencode({
      _id = rs.name
      protocolVersion = 1
      members: [
      for o in rs.nodes : {
        _id = index(rs.nodes, o)
        host = format("%s:%d", o.fqdn, o.mongod_port)
        votes = o.votes
        hidden = o.hidden
        priority = o.priority
        arbiterOnly = o.arbiter_only
      }]
    })
  })}

  csrs_replica_set  = var.config_replica_set != null ? local.replica_sets[var.config_replica_set.name] : null

  default_node = {
    mongos_port = null,
    mongod_port = null
  }

  rs_nodes = flatten([ for rs in local.replica_sets : [
    for node in rs.nodes : merge({
      rs_name    = rs.name,
      member     = index(rs.nodes, node)
    }, node)
  ]])

  nodes = { for node in concat(local.rs_nodes, local.parsed_router_nodes) : node.name => merge(local.default_node, node) }

  router_hosts     = [ for node in local.nodes : join(":", [node.fqdn, node.mongos_port]) if node.mongos_port != null ]
  router_uri       = format("mongodb://%s", join(",",slice(local.router_hosts, 0, min(3, length(local.router_hosts)))))

  mongo_cluster_uri = try("mongodb+srv://${replace(aws_route53_record.mongodb_srv_router[0].fqdn, "_mongodb._tcp.", "")}/?ssl=${var.enable_ssl}", null)
  mongo_rs_uri      = [ for r in aws_route53_record.mongodb_srv_rs : "mongodb+srv://${replace(r.fqdn, "_mongodb._tcp.", "")}/?ssl=${var.enable_ssl}" ]

  sharded          = length(local.router_hosts) > 0

  user_data = { for node in local.nodes : node.name => concat(
    [{
      filename = "base-init.cfg"
      content_type = "text/cloud-config"
      content = templatefile("${path.module}/templates/cloud-init-base.yaml", {
        mongodb_package     = var.mongodb_community ? "mongodb-org" : "mongodb-enterprise"
        mongodb_version     = var.mongodb_version
        repo_url            = var.mongodb_community ? "repo.mongodb.org" : "repo.mongodb.com"
        fqdn                = node.fqdn
        bootstrap_path      = local.bootstrap_path
        disable_thp_service = base64encode(file("${path.module}/scripts/disable-thp.service"))
        mongodb_nproc       = base64encode(file("${path.module}/scripts/99-mongodb-nproc.conf"))
        bootstrap           = base64encode(file("${path.module}/scripts/bootstrap.sh"))
      })
    }],
    node.mongod_port != null ? [{
      filename = "mongod-init.cfg"
      content_type = "text/cloud-config"
      content = templatefile("${path.module}/templates/cloud-init-mongod.yaml", {
        data_block_device  = var.ebs_block_device_name
        mount_point        = var.ebs_block_device_mount_point
        db_path            = local.db_path
        bootstrap_path     = local.bootstrap_path
        initiate_cmd       = node.member == 0 ? "initiate '${node.fqdn}:${node.mongod_port}' '${local.replica_sets[node.rs_name].cfg}'" : "null"
        add_shard_cmd      = local.sharded && node.member == 0 && !local.replica_sets[node.rs_name].is_config_rs ? "add_shard '${local.router_uri}' '${node.rs_name}' '${local.replica_sets[node.rs_name].hosts_csv}' '${local.replica_sets[node.rs_name].shard_name}'" : "null"
        readahead_service  = base64encode(templatefile("${path.module}/templates/readahead.service", {
          data_block_device = var.ebs_block_device_name
        }))
        mongod_conf        = base64encode(templatefile("${path.module}/templates/mongod.conf", {
          replSetName = node.rs_name
          clusterRole = local.replica_sets[node.rs_name].is_config_rs ? "configsvr" : local.sharded ? "shardsvr" : ""
          fqdn        = node.fqdn
          port        = node.mongod_port
          mongod_conf = var.mongod_conf
          db_path     = local.db_path
        }))
      })
    }] : [],
    node.mongos_port != null ? [{
      filename = "mongos-init.cfg"
      content_type = "text/cloud-config"
      content = templatefile("${path.module}/templates/cloud-init-mongos.yaml", {
        mongos_service = base64encode(file("${path.module}/scripts/mongos.service"))
        mongos_conf    = base64encode(templatefile("${path.module}/templates/mongos.conf",{
          csrs_name         = local.csrs_replica_set.name
          csrs_hosts        = local.csrs_replica_set.hosts_csv
          fqdn              = node.fqdn
          port              = node.mongos_port
          mongos_conf       = var.mongos_conf
        }))
      })
    }] : []
  )}

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
  count       = var.create ? 1 : 0

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
  count = var.create && var.ssh_from_security_group_only ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  description              = "SSH from Bastion"
  security_group_id        = aws_security_group.mongodb[0].id
  source_security_group_id = var.vpc_ssh_security_group_id
}

resource "aws_security_group_rule" "ssh_anywhere" {
  count = var.create && !var.ssh_from_security_group_only ? 1 : 0

  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  description              = "SSH from anywhere"
  security_group_id        = aws_security_group.mongodb[0].id
  cidr_blocks              = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "internal" {
  for_each = var.create ? { for o in local.mongodb_internal_ingess : o.description => o } : {}

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  description              = each.value.description
  security_group_id        = aws_security_group.mongodb[0].id
  self                     = true
}

resource "aws_security_group_rule" "external" {
  for_each = var.create ? { for o in local.mongodb_external_ingess : o.description => o } : {}

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  description              = each.value.description
  security_group_id        = aws_security_group.mongodb[0].id
  cidr_blocks              = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress" {
  count = var.create ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mongodb[0].id
}

data "template_cloudinit_config" "config" {
  for_each = local.user_data

  gzip          = var.create
  base64_encode = var.create

  dynamic "part" {
    for_each = each.value
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
      merge_type   = "list(append)+dict(recurse_array)+str()"
    }
  }
}

resource "aws_instance" "mongodb" {
  for_each = var.create ? local.nodes : {}

  ami                    = each.value.image_id
  instance_type          = each.value.instance_type
  key_name               = var.ssh_key_name
  vpc_security_group_ids = aws_security_group.mongodb[*].id
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

  user_data = data.template_cloudinit_config.config[each.value.name].rendered
}

resource "aws_route53_record" "mongodb" {
  for_each = { for k,v in local.nodes : k => v if var.create }

  zone_id = var.zone_id
  name    = each.value.fqdn
  type    = "A"
  ttl     = "300"
  records = [aws_instance.mongodb[each.key].private_ip]
}

## only for RS currently - need to change for mongos SRV
resource "aws_route53_record" "mongodb_srv_rs" {
  for_each = { for k,v in local.replica_sets : k => v if var.create }

  zone_id = var.zone_id
  name    = "_mongodb._tcp.${each.value.name}"
  type    = "SRV"
  ttl     = "300"
  records = [ for o in each.value.nodes : "0 0 ${o.mongod_port} ${o.fqdn}"]
}

resource "aws_route53_record" "mongodb_txt_rs" {
  for_each = local.replica_sets

  zone_id = var.zone_id
  name    = each.value.name
  type    = "TXT"
  ttl     = "300"
  records = [ "replicaSet=${each.value.name}&authSource=admin" ]
}

resource "aws_route53_record" "mongodb_srv_router" {
  count   = var.create && local.sharded ? 1 : 0

  zone_id = var.zone_id
  name    = "_mongodb._tcp.${var.name}"
  type    = "SRV"
  ttl     = "300"
  records = [ for node in local.nodes : "0 0 ${node.mongos_port} ${node.fqdn}" if node.mongos_port != null ]
}