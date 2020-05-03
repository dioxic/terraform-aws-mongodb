variable "ssh_key_name" {
	description = "AWS SSH key name"
}

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type        = map(string)
  default     = {}
}

variable "name" {
	description = "deployment name"
}

variable "domain_name" {
	description = "zone domain name"
	default     = "example.internal"
}

variable "mongodb_version" {
	description = "MongoDB version"
	default     = "4.2"
}

variable "ami_owner" {
	default = "amazon"
}

variable "ami_name" {
	default = "amzn2-ami-hvm-*-x86_64-gp2"
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