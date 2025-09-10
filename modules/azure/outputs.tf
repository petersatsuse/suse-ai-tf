output "public_ip" {
  description = "Public IP of the instance."
  value       = azurerm_public_ip.test_public_ip.ip_address
}

output "ssh_private_key_content" {
  description = "Content of the SSH private key."
  value       = var.use_existing_ssh_public_key ? var.user_ssh_private_key : one(tls_private_key.ssh_keypair[*]).private_key_openssh
  sensitive   = true
}

output "ssh_public_key_content" {
  description = "Content of the SSH public key."
  value       = var.use_existing_ssh_public_key ? var.user_ssh_public_key : one(tls_private_key.ssh_keypair[*]).public_key_openssh
}

output "ssh_user" {
  description = "The SSH user for the created VM."
  value       = var.ssh_user
}
