variable "domain_name" {
  description = "The hosted zone domain."
  default     = ""
}

variable "name" {
  description = "The node name."
  default     = ""
}

variable "mongod_port" {
  description = "mongod port, defaults to `27017`"
  type        = number
  default     = 27017
}

variable "mongos_port" {
  description = "mongos port, defaults to `27016`"
  type        = number
  default     = 27016
}

variable "shard_ami" {
  description = "Machine image for config server hosts. Required."
}

variable "csrs_ami" {
  description = "Machine image for config server hosts. Required."
}

variable "shard_instance_type" {
  description = "AWS instance type for shard host (e.g. m4.large), defaults to \"t2.micro\"."
  default     = "t2.micro"
}

variable "csrs_instance_type" {
  description = "AWS instance type for config server host (e.g. m4.large), defaults to \"t2.micro\"."
  default     = "t2.micro"
}

variable "cohost_mongos" {
  type    = bool
  default = true
}

variable "mongod_conf" {
  description = "Additional config to add to mongod.conf file."
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

variable "vpc_id" {
  description = "VPC ID to provision mongodb. Required."
  default     = ""
}

variable "subnet_id" {
  description = "Subnet id for the MongoDB server(s). Required."
  default     = ""
}

variable "zone_id" {
  description = "Existing route53 private host zone id"
  default     = ""
}

variable "user_data" {
  description = "user_data script to pass in at runtime."
  default     = ""
}

variable "mongod_conf" {
  description = "extra mongod configuration."
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

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type        = map(string)
  default     = {}
}