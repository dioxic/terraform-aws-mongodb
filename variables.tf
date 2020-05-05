variable "domain_name" {
  description = "The domain name."
  default     = ""
}

variable "name" {
  description = "The node name."
  default     = ""
}

variable "create" {
  description = "Create resources, default `true`"
  type        = bool
  default     = true
}

variable "data_replica_sets" {
  description = "Replica set configuration for data"
  type        = list(object({
    name  = string
    shard_name    = string
    nodes = list(object({
      arbiter_only  = bool
      hidden        = bool
      fqdn          = string
      image_id      = string
      instance_type = string
      mongod_port   = number
      mongos_port   = number
      name          = string
      priority      = number
      volume_iops   = number
      volume_size   = number
      volume_type   = string
      votes         = number
    }))
  }))
}

variable "config_replica_set" {
  description = "Replica set configuration for config server"
  type        = object({
    name  = string
    nodes = list(object({
      arbiter_only  = bool
      hidden        = bool
      fqdn          = string
      image_id      = string
      instance_type = string
      mongod_port   = number
      name          = string
      priority      = number
      volume_iops   = number
      volume_size   = number
      volume_type   = string
      votes         = number
    }))
  })
  default     = null
}

variable "router_nodes" {
  description = "Standalone router node configuration"
  type        = list(object({
    name          = string
    fqdn          = string
    image_id      = string
    instance_type = string
    mongos_port   = number
  }))
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

variable "mongodb_community" {
  description = "MongoDB community version, defaults to `true`."
  type        = bool
  default     = true
}

variable "enable_ssl" {
  description = "Enable SSL for MongoDB connections, defaults to `false`."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID to provision mongodb. Required."
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet ids for the MongoDB server(s). Required."
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Existing route53 private host zone id"
  default     = ""
}

variable "user_data" {
  description = "user_data script to pass in at runtime."
  default     = ""
}

variable "ssh_key_name" {
  description = "AWS key name you will use to access the MongoDB host instance(s). Required."
  default     = ""
}

variable "vpc_security_group_ids" {
  description = "VPC security group ids to apply to the EC2 instance. Required."
  type        = list(string)
  default     = []
}

variable "vpc_ssh_security_group_id" {
  description = "VPC security group id to allow SSH access to the EC2 instances. Required."
  default     = ""
}

variable "ssh_from_security_group_only" {
  description = "only allow the specified security group to SSH to mongo hosts. Set true if `vpc_ssh_security_group_id` is provided."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type        = map(string)
  default     = {}
}