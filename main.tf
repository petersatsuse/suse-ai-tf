module "rke2_node" {
  source = ./modules/infrastructure
  instance_prefix = var.instance_prefix
  instance_type   = var.instance_type
  use_existing_ssh_public_key = var.use_existing_ssh_public_key
  user_ssh_private_key = var.user_ssh_private_key
  user_ssh_public_key = var.user_ssh_public_key
  registration_code = var.registration_code
}

module "k8s_resources" {
  source = ./modules/kubernetes
  registry_name = var.registry_name
  registry_secretname = var.registry_secretname
  registry_username = var.registry_username
  registry_password = var.registry_password
  suse_ai_namespace = var.suse_ai_namespace
  cert_manager_namespace = var.cert_manager_namespace
}
