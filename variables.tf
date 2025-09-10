variable "cloud_provider" {
  description = "The cloud provider to deploy to. Must be 'aws' or 'azure'."
  type        = string
}

variable "instance_prefix" {
  type        = string
  default     = "suse-ai"
  description = "Prefix added to names of instance"
}

variable "ssh_user" {
  description = "The SSH username for the virtual machine (e.g., 'azureuser' or 'ec2-user')."
  type        = string
}

variable "region" {
  type        = string
  description = "Specifies the region to deploy all resources"
}

variable "instance_type" {
  type        = string
  default     = ""
  description = "Type of instance, e.g AWS: g4dn.xlarge or Azure: xxx"
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "azure_image" {
  description = "The Azure VM image to use, in the format 'publisher:offer:sku:version'."
  type        = string
  default     = ""
}

variable "aws_ami" {
  description = "The AMI ID to use for the AWS instance."
  type        = string
  default     = ""
}

variable "use_existing_ssh_public_key" {
  type        = bool
  default     = false
  description = "Boolean to check if using existing SSH key"
}

variable "user_ssh_private_key" {
  type        = string
  default     = null
  description = "SSH Private key path"
}

variable "user_ssh_public_key" {
  type        = string
  default     = null
  description = "SSH Public key path"
}

variable "registration_code" {
  type        = string
  description = "SUSE registration code for SLE Micro"
}

variable "registry_name" {
  type        = string
  default     = "dp.apps.rancher.io"
  description = "Name of the application collection registry"
}

variable "registry_secretname" {
  type        = string
  default     = "application-collection"
  description = "Name of the secret for accessing the registry"
}

variable "registry_username" {
  type        = string
  description = "Username for the registry"
}

variable "registry_password" {
  type        = string
  description = "Password/Token for the registry"
  sensitive   = true
}

variable "kubeconfig_path" {
  type        = string
  description = "kubeconfig file for accessing cluster"
  default     = null
}

variable "suse_ai_namespace" {
  type        = string
  default     = "suse-ai"
  description = "Name of the namespace where you want to deploy SUSE AI Stack!"
}

variable "cert_manager_namespace" {
  type        = string
  default     = "cert-manager"
  description = "Name of the namespace where you want to deploy cert-manager"
}

variable "gpu_operator_ns" {
  type        = string
  default     = "gpu-operator-resources"
  description = "Namespace for the NVIDIA GPU operator"
}
