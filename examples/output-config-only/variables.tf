
variable "name" {
	description = "deployment name"
	default     = "test"
}

variable "domain_name" {
	description = "zone domain name"
	default     = "example.internal"
}

variable "mongodb_version" {
	description = "MongoDB version"
	default     = "4.2"
}