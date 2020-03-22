output "zREADME" {
  value = <<README
# ------------------------------------------------------------------------------
# ${var.name} Network
# ------------------------------------------------------------------------------
A private RSA key has been generated and downloaded locally. The file
permissions have been changed to 0600 so the key can be used immediately for
SSH or scp.
If you're not running Terraform locally (e.g. in TFE or Jenkins) but are using
remote state and need the private key locally for SSH, run the below command to
download.
  ${format("$ echo \"$(terraform output private_key_pem)\" \\\n      > %s \\\n      && chmod 0600 %s", var.private_key_file == "" ? module.ssh_keypair_aws.private_key_filename : var.private_key_file, var.private_key_file == "" ? module.ssh_keypair_aws.private_key_filename : var.private_key_file)}
Run the below command to add this private key to the list maintained by
ssh-agent so you're not prompted for it when using SSH or scp to connect to
hosts with your public key.
  ${format("$ ssh-add %s", var.private_key_file == "" ? module.ssh_keypair_aws.private_key_filename : var.private_key_file)}
The public part of the key loaded into the agent ("public_key_openssh" output)
has been placed on the target system in ~/.ssh/authorized_keys.
  ${join("", formatlist("\n  $ ssh -A -i %s %s@%s\n", var.private_key_file == "" ? module.ssh_keypair_aws.private_key_filename : var.private_key_file, lookup(var.users, var.os), module.bastion.public_ip))}${var.private_key_file == "" ?
"\nTo force the generation of a new key, the private key instance can be \"tainted\" \n using the below command if the private key was not overridden. \n $ terraform taint -module=network_aws.ssh_keypair_aws.tls_private_key \\\n      tls_private_key.key"
:
"\nThe SSH key was generated outside of this module and overridden."}
README
}

output "vpc_cidr" {
  value = var.create_vpc ? module.vpc.vpc_cidr_block : var.vpc_cidr
}

output "vpc_id" {
  value = var.create_vpc ? module.vpc.vpc_id : var.vpc_id
}

output "bastion_security_group" {
  value = module.bastion_sg.this_security_group_id
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "bastion_username" {
  value = "${lookup(var.users, var.os)}"
}

output "private_key_name" {
  value = "${module.ssh_keypair_aws.private_key_name}"
}

output "private_key_filename" {
  value = "${module.ssh_keypair_aws.private_key_filename}"
}

output "private_key_pem" {
  value = "${module.ssh_keypair_aws.private_key_pem}"
}

output "public_key_pem" {
  value = "${module.ssh_keypair_aws.public_key_pem}"
}

output "public_key_openssh" {
  value = "${module.ssh_keypair_aws.public_key_openssh}"
}

output "ssh_key_name" {
  value = "${module.ssh_keypair_aws.name}"
}