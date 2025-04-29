terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "kubernetes" {
  config_path = "${path.module}/kubeconfig-rke2.yaml"
}
