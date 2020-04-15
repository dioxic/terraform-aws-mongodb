bastion_count     = 1
name              = "markbm-tf"
ssh_key_name      = "markbm"
mongodb_version   = "4.2"
#vpc_id            = "vpc-344d5d51"
create_vpc        = true
create_zone       = false
#zone_id           = "Z102245739PGYCL7XC95E"
#subnet_ids        = [ "subnet-11e21975","subnet-03b28a5a","subnet-11e21975"]
vpc_cidrs_private = ["10.0.1.0/24"]
vpc_cidrs_public  = ["10.0.11.0/24"]
vpc_cidr          = "10.0.0.0/16"
domain_name = "example.com"
tags = {
	owner="mark.baker-munton"
}