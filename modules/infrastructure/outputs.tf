output "ec2_public_ip" {
  value = aws_eip.ec2_eip.public_ip
}

output "kubeconfig_path" {
  value = "${path.root}/modules/infrastructure/kubeconfig-rke2.yaml"
}

output "ssh_private_key_content" {
  value     = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
  sensitive = true
}
