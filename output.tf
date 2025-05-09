output "instance_public_ip" {
  description = "Public IP of the SUSE Micro instance"
  value       = module.rke2_node.ec2_public_ip
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = module.rke2_node.kubeconfig_path
}

#output "elastic_ip" {
#  value = module.rke2_node.ec2_eip.public_ip
#}
