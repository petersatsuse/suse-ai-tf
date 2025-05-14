terraform {
  required_providers {
    ssh = {
      source  = "loafoe/ssh"
      version = "2.7.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
