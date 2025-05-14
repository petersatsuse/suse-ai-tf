data "aws_ami" "suse_sle_micro6" {
  most_recent = true

  owners = ["013907871322"]

  filter {
    name   = "name"
    values = ["suse-sle-micro-6-1-byos-v20250210-hvm-ssd-x86_64"]
  }
}
