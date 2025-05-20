data "aws_ami" "suse_sle_micro6" {
  most_recent = true

  owners = ["013907871322"]

  filter {
    name   = "name"
    values = ["suse-sle-micro-6-1-byos-v20250210-hvm-ssd-x86_64"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "local_file" "ssh_public_key" {
  count    = var.use_existing_ssh_public_key ? 1 : 0
  filename = var.user_ssh_public_key
}

data "local_file" "ssh_private_key" {
  count    = var.use_existing_ssh_public_key ? 1 : 0
  filename = var.user_ssh_private_key
}
