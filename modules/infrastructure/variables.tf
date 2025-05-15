variable "instance_prefix" {
  type        = string
  default     = null
  description = "Prefix added to names of EC2 instance"
}

variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "Specifies the AWS region to deploy all resources"
}

variable "instance_type" {
  type        = string
  default     = "g4dn.xlarge"
  description = "Type of EC2 instance"
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

