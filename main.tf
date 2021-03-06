terraform {
  required_version = ">= 0.12.20"
}

locals {
  bootstrap_path              = "/var/lib/cloud/scripts/bootstrap.sh"
  data_block_device           = "/dev/${var.ebs_block_device_name}"
  db_path                     = "${var.ebs_block_device_mount_point}/db"

  create_zone                 = var.create && var.create_zone
  create_zone_records         = var.create && (var.create_zone_records || var.create_zone)
  create_security_group       = var.create && var.create_security_group
  create_security_group_rules = var.create && (var.create_security_group_rules || var.create_security_group)

  subnet_count = length(var.subnet_ids)

  zone_id           = local.create_zone ? aws_route53_zone.mongodb[0].id : var.zone_id
  security_group_id = local.create_security_group ? aws_security_group.mongodb[0].id : var.security_group_id

  rs_cfg = { for name,rs in var.replica_sets : name => {
      _id = name
      protocolVersion = 1
      members: [for i,o in rs.members : {
        _id = i
        host = "${o.name}.${var.domain_name}:${o.mongod_port}"
        votes = o.votes
        hidden = o.hidden
        priority = o.priority
        arbiterOnly = o.arbiter_only
      }]
    }
  }

  rs_nodes = flatten([ for name,rs in var.replica_sets : [
    for i,o in rs.members : {
      rs_name        = name
      bootstrap      = i == 0
      name           = o.name
      arbiter        = o.arbiter_only
      mongod_port    = o.mongod_port
      mongos_port    = o.mongos_port
      image_id       = o.image_id
      instance_type  = o.instance_type
      volume_iops    = o.volume_iops
      volume_size    = o.volume_size
      volume_type    = o.volume_type
      idx            = i
    }
  ]])

  router_nodes = [ for i,node in var.router_nodes : merge(
    node,
    {
      idx = i
    })
  ]

  nodes = { for node in concat(local.rs_nodes, local.router_nodes) : node.name => merge(
    {
      mongos_port = null
      mongod_port = null
    },
    {
      fqdn        = "${node.name}.${var.domain_name}"
      mongod_host = try("${node.name}.${var.domain_name}:${node.mongod_port}", null)
      mongos_host = try("${node.name}.${var.domain_name}:${node.mongos_port}", null)
    },
    node)
  }

  replica_sets = { for name,rs in var.replica_sets : name => {
      config_server = rs.config_server
      shard_name    = rs.shard_name
      hosts         = local.rs_cfg[name].members[*].host
      cfg           = local.rs_cfg[name]
    }
  }

  config_replica_set  = try([ for name,rs in local.replica_sets : merge({name: name}, rs) if rs.config_server][0], null)

  router_hosts     = [ for node in local.nodes : join(":", [node.fqdn, node.mongos_port]) if node.mongos_port != null ]
  router_uri       = format("mongodb://%s", join(",",slice(local.router_hosts, 0, min(3, length(local.router_hosts)))))

  mongo_cluster_uri = local.sharded ? "mongodb+srv://${var.cluster_name}.${var.domain_name}/?ssl=${var.enable_ssl}" : null
  mongo_rs_uri      = [ for name,rs in local.replica_sets : "mongodb+srv://${name}.${var.domain_name}/?ssl=${var.enable_ssl}" ]

  sharded          = length(local.router_hosts) > 0

  mongod_conf = { for node in local.nodes : node.name => templatefile("${path.module}/templates/mongod.conf", {
    replSetName = node.rs_name
    clusterRole = local.replica_sets[node.rs_name].config_server ? "configsvr" : local.sharded ? "shardsvr" : ""
    fqdn        = node.fqdn
    port        = node.mongod_port
    mongod_conf = var.mongod_conf
    db_path     = local.db_path
  }) if node.mongod_port != null }

  mongos_conf = { for node in local.nodes : node.name => templatefile("${path.module}/templates/mongos.conf",{
    csrs_name         = local.config_replica_set.name
    csrs_hosts        = join(",", local.config_replica_set.hosts)
    fqdn              = node.fqdn
    port              = node.mongos_port
    mongos_conf       = var.mongos_conf
  }) if node.mongos_port != null }

  user_data = { for node in local.nodes : node.name => concat(
    [{
      filename = "base-init.cfg"
      content_type = "text/cloud-config"
      content = templatefile("${path.module}/templates/cloud-init-base.yaml", {
        mongodb_package     = var.enterprise_binaries ? "mongodb-enterprise" : "mongodb-org"
        mongodb_version     = var.mongodb_version
        repo_url            = var.enterprise_binaries ? "repo.mongodb.com" : "repo.mongodb.org"
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
        initiate           = node.bootstrap
        add_shard          = node.bootstrap && local.sharded && !local.replica_sets[node.rs_name].config_server
        fqdn               = node.fqdn
        port               = node.mongod_port
        rs_name            = node.rs_name
        rs_hosts           = local.replica_sets[node.rs_name].hosts
        rs_config          = local.replica_sets[node.rs_name].cfg
        shard_name         = local.replica_sets[node.rs_name].shard_name
        router_uri         = local.router_uri
        mongod_conf        = base64encode(local.mongod_conf[node.name])
        readahead_service  = base64encode(templatefile("${path.module}/templates/readahead.service", {
          data_block_device  = var.ebs_block_device_name
        }))
      })
    }] : [],
    node.mongos_port != null ? [{
      filename = "mongos-init.cfg"
      content_type = "text/cloud-config"
      content = templatefile("${path.module}/templates/cloud-init-mongos.yaml", {
        mongos_service = base64encode(file("${path.module}/scripts/mongos.service"))
        mongos_conf    = base64encode(local.mongos_conf[node.name])
      })
    }] : []
  )}

  mongo_ingress_ports = distinct(concat(
    [ for o in local.nodes : {
      port        = o.mongod_port
      description = local.replica_sets[o.rs_name].config_server ? "MongoDB Config Server" : local.sharded ? "MongoDB Shard" : "MongoDB Replica Set"
    } if o.mongod_port != null ],
    [ for o in local.nodes : {
      port        = o.mongos_port
      description = "MongoDB Router"
    } if o.mongos_port != null ]
  ))

  ssh_ingress_ports = {
    port = 22
    description = "SSH"
  }

  mongo_ingress_self  = [ for o in local.mongo_ingress_ports : merge(o, { self = true }) ]
  mongo_ingress_cidr  = [
    for o in local.mongo_ingress_ports : merge(o, { cidr_blocks = var.mongo_ingress_with_cidr_blocks })
    if length(var.mongo_ingress_with_cidr_blocks) > 0
  ]
  mongo_ingress_sg = flatten([ for o in local.mongo_ingress_ports :
    [ for sg in var.mongo_ingress_with_security_group_ids : merge(o, { security_group = sg }) ]
  ])

  ssh_ingress_self  = var.ssh_ingress_with_self ? [ merge(local.ssh_ingress_ports, { self = true }) ] : []
  ssh_ingress_cidr  = length(var.ssh_ingress_with_cidr_blocks) > 0 ? [ merge(local.ssh_ingress_ports, { cidr_blocks = var.ssh_ingress_with_cidr_blocks }) ] : []
  ssh_ingress_sg    = [ for sg in var.ssh_ingress_with_security_group_ids : merge(local.ssh_ingress_ports, { security_group = sg }) ]

}

resource "aws_security_group" "mongodb" {
  count = local.create_security_group ? 1 : 0

  name_prefix = "${var.cluster_name}-mongodb-"
  vpc_id      = var.vpc_id
  description = "MongoDB security group"

  tags        = merge(
    {
      "Name" = "${var.cluster_name}-mongodb"
    },
    var.tags
  )
}

resource "aws_security_group_rule" "ingress_with_security_group" {
  for_each = local.create_security_group_rules ? { for rule in concat(local.ssh_ingress_sg, local.mongo_ingress_sg) : rule.description => rule} : {}

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  description              = each.value.description
  source_security_group_id = each.value.security_group
  security_group_id        = local.security_group_id
}

resource "aws_security_group_rule" "ingress_with_cidr" {
  for_each = local.create_security_group_rules ? { for rule in concat(local.ssh_ingress_cidr, local.mongo_ingress_cidr) : rule.description => rule } : {}

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  description              = each.value.description
  cidr_blocks              = each.value.cidr_blocks
  security_group_id        = local.security_group_id
}

resource "aws_security_group_rule" "ingress_with_self" {
  for_each = local.create_security_group_rules ? { for rule in concat(local.ssh_ingress_self, local.mongo_ingress_self) : rule.description => rule } : {}

  type                     = "ingress"
  from_port                = each.value.port
  to_port                  = each.value.port
  protocol                 = "tcp"
  description              = each.value.description
  self                     = true
  security_group_id        = local.security_group_id
}

resource "aws_security_group_rule" "egress" {
  count = local.create_security_group_rules ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = local.security_group_id
}

data "template_cloudinit_config" "mongodb" {
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
  vpc_security_group_ids = [ local.security_group_id ]
  subnet_id              = element(
    var.subnet_ids,
    each.value.idx % local.subnet_count
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

  user_data = data.template_cloudinit_config.mongodb[each.key].rendered
}

resource "aws_route53_zone" "mongodb" {
  count = local.create_zone ? 1 : 0

  name  = var.domain_name

  vpc {
    vpc_id = var.vpc_id
  }

  tags = var.tags
}

resource "aws_route53_record" "mongodb" {
  for_each = { for k,v in local.nodes : k => v if local.create_zone_records }

  zone_id = local.zone_id
  name    = each.value.fqdn
  type    = "A"
  ttl     = "300"
  records = [aws_instance.mongodb[each.key].private_ip]
}

resource "aws_route53_record" "mongodb_srv_rs" {
  for_each = { for k,v in local.replica_sets : k => v if local.create_zone_records }

  zone_id = local.zone_id
  name    = "_mongodb._tcp.${each.key}"
  type    = "SRV"
  ttl     = "300"
  records = [ for node in local.nodes : "0 0 ${node.mongod_port} ${node.fqdn}" if node.rs_name == each.key]
}

resource "aws_route53_record" "mongodb_txt_rs" {
  for_each = { for k,v in local.replica_sets : k => v if local.create_zone_records }

  zone_id = local.zone_id
  name    = each.key
  type    = "TXT"
  ttl     = "300"
  records = [ "replicaSet=${each.key}&authSource=admin" ]
}

resource "aws_route53_record" "mongodb_srv_router" {
  count   = local.create_zone_records && local.sharded ? 1 : 0

  zone_id = local.zone_id
  name    = "_mongodb._tcp.${var.cluster_name}"
  type    = "SRV"
  ttl     = "300"
  records = [ for node in local.nodes : "0 0 ${node.mongos_port} ${node.fqdn}" if node.mongos_port != null ]
}