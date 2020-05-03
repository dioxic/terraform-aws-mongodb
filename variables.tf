variable "zone_domain" {
  description = "The hosted zone domain."
  default     = ""
}

variable "name" {
  description = "The node name."
  default     = ""
}

variable "config_mongod_port" {
  description = "mongod port for config server, defaults to `27019`"
  type        = number
  default     = 27019
}

variable "sharded_mongod_port" {
  description = "mongod port with sharded topology, defaults to `27018`"
  type        = number
  default     = 27018
}

variable "mongod_port" {
  description = "mongod port with unsharded topology, defaults to `27017`"
  type        = number
  default     = 27017
}

variable "mongos_port" {
  description = "mongos port, defaults to `27017`"
  type        = number
  default     = 27017
}

variable "shard_count" {
  type    = number
  default = 1
}

variable "member_count" {
  type    = number
  default = 3
}

variable "sharded" {
  type    = bool
  default = false
}

variable "cohost_mongos" {
  type    = bool
  default = true
}

variable "mongos_count" {
  type    = number
  default = -1
}

variable "data_replica_sets" {
  description = "Replica set configuration for data"
  type        = list(object({
    name  = string
    nodes = list(object({
      name          = string
      priority      = number
      votes         = number
      hidden        = bool
      isArbiter     = bool
      mongod_port   = number
      mongos_port   = number
      image_id      = string
      instance_type = string
    }))
  }))
}

variable "config_replica_sets" {
  description = "Replica set configuration for config server"
  type        = object({
    name  = string
    nodes = list(object({
      name          = string
      priority      = number
      votes         = number
      hidden        = bool
      isArbiter     = bool
      mongod_port   = number
      mongos_port   = number
      image_id      = string
      instance_type = string
    }))
  })
  default     = null
}

variable "image_id" {
  description = "Machine image for mongodb server hosts. Required."
}

variable "config_image_id" {
  description = "Machine image for config server hosts, defaults to `image_id`"
  default     = ""
}

variable "router_image_id" {
  description = "Machine image for router server hosts, defaults to `image_id`"
  default     = ""
}

variable "instance_type" {
  description = "AWS instance type for mongodb host (e.g. m4.large), defaults to \"t2.micro\"."
  default     = "t2.micro"
}

variable "config_instance_type" {
  description = "AWS instance type for config server host (e.g. m4.large), defaults to `instance_type`"
  default     = ""
}

variable "router_instance_type" {
  description = "AWS instance type for router server host (e.g. m4.large), defaults to `instance_type`."
  default     = ""
}

variable "data_block_device_name" {
    description = "Block device name for data, default \"xvdb\""
    default     = "xvdb"
}

variable "data_block_device_volume_type" {
    description = "Volume type for data device , default \"gp2\""
    default     = "gp2"
}

variable "data_block_device_iops" {
    description = "IOPS for data device, if using io1 volume type."
    default     = -1
}

variable "data_block_device_volume_size" {
    description = "Volume size (GB) for data device."
    type        = number
}

variable "data_mount_point" {
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
  description = "MongoDB community version, defaults to `false`."
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