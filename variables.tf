variable "domain_name" {
  description = "The domain name for the cluster. Ignored if `create_zone` is false."
  default     = null
}

variable "cluster_name" {
  description = "The cluster name. Required if `sharded`"
  default     = null
}

variable "create" {
  description = "Create resources, default `true`"
  type        = bool
  default     = true
}

variable "create_zone" {
  description = "Creates private hosted zone with name `domain_name` in the `vpc_id`."
  type        = bool
  default     = false
}

variable "create_zone_records" {
  description = "Create route53 zone records for MongoDB. `create_zone` must be true or `zone_id` must be provided."
  type        = bool
  default     = false
}

variable "create_security_group" {
  description = "Creates a security group for MongoDB, defaults to `true`"
  type        = bool
  default     = true
}

variable "replica_sets" {
  description = "Replica set configuration for data"
  type        = map(object({
    shard_name       = string
    config_server    = bool
    members          = list(object({
      arbiter_only     = bool
      hidden           = bool
      image_id         = string
      instance_type    = string
      mongod_port      = number
      mongos_port      = number
      name             = string
      priority         = number
      volume_iops      = number
      volume_size      = number
      volume_type      = string
      votes            = number
    }))
  }))
}

variable "router_nodes" {
  description = "Standalone router node configuration"
  type        = list(object({
    name          = string
    image_id      = string
    instance_type = string
    mongos_port   = number
  }))
  default = []
}

variable "ebs_block_device_name" {
  description = "Block device name for data, default \"xvdb\""
  default     = "xvdb"
}

variable "ebs_block_device_mount_point" {
  description = "MongoDB data mount point, default \"/data\""
  default     = "/data"
}

variable "mongod_conf" {
  description = "Additional config to add to mongod.conf file."
  default     = ""
}

variable "mongos_conf" {
  description = "Additional config to add to mongos.conf file."
  default     = ""
}

variable "mongodb_version" {
  description = "MongoDB version tag (e.g. 4.0.0 or 4.0.0-ent), defaults to \"4.2\"."
  default     = "4.2"
}

variable "enterprise_binaries" {
  description = "MongoDB Enterprise version, defaults to `false`."
  type        = bool
  default     = false
}

variable "enable_ssl" {
  description = "Enable SSL for MongoDB connections, defaults to `false`."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID to provision mongodb. Required."
}

variable "subnet_ids" {
  description = "Subnet ids for the MongoDB server(s). Required."
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Existing route53 private host zone id."
  default     = null
}

variable "user_data" {
  description = "user_data script to pass in at runtime."
  default     = null
}

variable "ssh_key_name" {
  description = "AWS key name you will use to access the MongoDB host instance(s). Required."
}

variable "vpc_security_group_ids" {
  description = "VPC security group ids to apply to the EC2 instance."
  type        = list(string)
  default     = []
}

variable "ssh_ingress_with_security_group_ids" {
  description = "List of security group ids allowed to ingress on SSH port."
  type        = list(string)
  default     = []
}

variable "ssh_ingress_with_cidr_blocks" {
  description = "List of CIDRs allowed to ingress on SSH port. Defaults to [\"0.0.0.0/0\"]."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "mongo_ingress_with_security_group_ids" {
  description = "List of security group ids allowed to ingress on MongoDB port(s)."
  type        = list(string)
  default     = []
}

variable "mongo_ingress_with_cidr_blocks" {
  description = "List of CIDRs allowed to ingress on MongoDB port(s). Defaults to [\"0.0.0.0/0\"]."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type        = map(string)
  default     = {}
}