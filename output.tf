output "instance_public_ip" {
  description = "Public IP of the SUSE Micro instance"
  value       = module.rke2_node.ec2_public_ip
}

output "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  value       = local_file.kube_config_yaml.filename
}

output "next_steps" {
  description = "Follow these steps for accessing SUSE AI"
  value       = <<EOT
  To access SUSE AI WebUI interface through your web browser, 
  add below entry in your system's /etc/hosts file:
  
  <PUBLIC_IP_OF_EC2_INSTANCE>  suse-ollama-webui 

  And then access via https://suse-ollama-webui

  You should see a singup/login page, please signup for the first user, this user will have the admin privileges.
  EOT
}
