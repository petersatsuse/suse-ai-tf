output "public_ip" {
  description = "Public IP of the instance."
  value       = azurerm_public_ip.main.ip_address
}

output "ssh_private_key_content" {
  description = "Content of the SSH private key."
  value       = var.use_existing_ssh_public_key ? var.user_ssh_private_key : one(tls_private_key.ssh_keypair[*]).private_key_openssh
  sensitive   = true
}

output "ssh_user" {
  description = "The SSH user for the created VM."
  value       = var.ssh_user
}
