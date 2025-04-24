#output "instance_public_ip" {
#  description = "Public IP of the SUSE Micro instance"
#  value       = aws_instance.sle_micro_6.public_ip
#}

output "elastic_ip" {
  value = aws_eip.ec2_eip.public_ip
}
