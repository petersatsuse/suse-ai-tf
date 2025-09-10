locals {
  is_azure = lower(var.cloud_provider) == "azure"
  is_aws   = lower(var.cloud_provider) == "aws"

  active_infra_outputs = one(concat(module.cloud, module.cloud)) # This will be correctly populated by one of the modules below

  kc_file_name = var.kubeconfig_path == null ? "${path.cwd}/${var.instance_prefix}-kubeconfig-rke2.yaml" : var.kubeconfig_path
}

# The "cloud" module dynamically sources the correct cloud-specific module.
module "cloud" {
  source = local.is_azure ? "./modules/azure" : "./modules/aws"

  # Pass all relevant variables
  region                      = var.region
  instance_prefix             = var.instance_prefix
  instance_type               = var.instance_type
  ssh_user                    = var.ssh_user
  common_tags                 = var.common_tags
  registration_code           = var.registration_code
  use_existing_ssh_public_key = var.use_existing_ssh_public_key
  user_ssh_private_key        = var.user_ssh_private_key

  # Pass cloud-specific variables
  # AWS
  ami                      = var.aws_ami
  user_ssh_public_key_name = var.user_ssh_public_key_name
  # Azure
  image                = var.azure_image
  user_ssh_public_key  = var.user_ssh_public_key
}

# Create a local file signal to indicate when infrastructure is ready
#resource "local_file" "kubeconfig_ready_signal" {
#  filename        = "${path.root}/.kubeconfig-ready"
#  content         = "Kubeconfig is ready at ${timestamp()}"
#  file_permission = "0644"

#  depends_on = [module.rke2_node]
#}

#resource "null_resource" "wait_for_kubeconfig" {
#  triggers = {
#    kubeconfig_ready = timestamp() # Force re-evaluation
#  }

#  provisioner "local-exec" {
#    command = "while [ ! -f ${path.root}/modules/infrastructure/kubeconfig-rke2.yaml ]; do sleep 5; done"
#  }

#  depends_on = [module.rke2_node]
#}

#data "local_file" "kubeconfig" {
#  filename = "${path.root}/modules/infrastructure/kubeconfig-rke2.yaml"

#  depends_on = [null_resource.wait_for_kubeconfig]
#}

#resource "local_file" "kube_config_yaml" {
#  filename        = "${path.root}/modules/infrastructure/${var.instance_prefix}-kubeconfig-rke2.yaml"
#  file_permission = "0600"
#  content         = data.local_file.kubeconfig.content

#  depends_on = [data.local_file.kubeconfig]
#}

# Setup Kubernetes Provider
#provider "kubernetes" {
#  alias       = "k8s"
#  config_path = local_file.kube_config_yaml.filename
#}

#provider "helm" {
#  kubernetes {
#    config_path = local_file.kube_config_yaml.filename
#  }

#  registry {
#    url      = "oci://${var.registry_name}"
#    username = var.registry_username
#    password = var.registry_password
#  }
#}

# The "kubernetes" module handles all application deployment
module "kubernetes" {
  source = "./modules/kubernetes"
  count  = module.cloud.public_ip != null ? 1 : 0

  # Pass connection details from the cloud module's output
  public_ip               = module.cloud.public_ip
  ssh_user                = module.cloud.ssh_user
  ssh_private_key_content = module.cloud.ssh_private_key_content

  # Pass through application variables
  registry_name       = var.registry_name
  registry_username   = var.registry_username
  registry_password   = var.registry_password
  suse_ai_namespace   = var.suse_ai_namespace
  gpu_operator_ns     = var.gpu_operator_ns
  registry_secretname = var.registry_secretname
}

# The kubeconfig is written here in the root, using the final output from the k8s module.
resource "local_file" "kube_config_yaml" {
  count = length(module.kubernetes) > 0 ? 1 : 0

  filename        = local.kc_file_name
  content         = one(module.kubernetes[*]).kubeconfig_content
  file_permission = "0600"
}
