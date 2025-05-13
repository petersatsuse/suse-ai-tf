variable "instance_prefix" {
  type    = string
  default = null
}

variable "instance_type" {
  type    = string
  default = "g4dn.xlarge"
}

variable "use_existing_ssh_public_key" {
  type    = bool
  default = false
}

variable "user_ssh_private_key" {
  type    = string
  default = null
}

variable "user_ssh_public_key" {
  type    = string
  default = null
}

variable "registration_code" {
  type    = string
  default = null
}

