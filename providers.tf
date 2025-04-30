terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17.0"
    }
  }
}

provider "kubernetes" {
  alias       = "k8s"
  config_path = "${path.module}/kubeconfig-rke2.yaml"
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/kubeconfig-rke2.yaml"
  }
  registry {
    url      = "oci://${var.registry_name}"
    username = var.registry_username
    password = var.registry_password
  }
}

