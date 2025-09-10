output "instance_public_ip" {
  description = "Public IP of the created VM (SUSE Micro) instance"
  value       = module.cloud.public_ip
}

output "kubeconfig_file_location" {
  description = "Path to the generated Kubeconfig file on your local machine."
  value       = length(local_file.kube_config_yaml) > 0 ? local_file.kube_config_yaml[0].filename : "Kubeconfig not generated."
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
