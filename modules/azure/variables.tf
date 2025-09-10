variable "image" { # This will be the SLE Micro 6 URN e.g. suse:sle-micro-6-0-byos:gen2:2025.05.13
  type        = string
  default     = "suse:sle-micro-6-0-byos:gen2:2025.05.13"
  description = "URN for the Azure VM image (e.g., SUSE Linux Enterprise Micro 6)."
}

variable "instance_prefix" {
  type        = string
  default     = "suse-ai"
  description = "Prefix added to names of the instance"
}

variable "common_tags" {
  type = map(string)
  default = null
}

variable "region" {
  type        = string
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "ssh_user" {
  type        = string
  description = "The username for the local account that will be created on the new VM."
  default     = "azureadmin"
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
  default     = null
  description = "SUSE registration code"
}

variable "instance_type" {
  type        = string
  default     = null
  description = "Instance type"
}
