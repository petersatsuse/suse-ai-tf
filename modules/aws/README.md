# Terraform AWS EC2 + SLE Micro 6.1 + RKE2 Setup

This Terraform module provisions an **Amazon EC2** instance running **SLE Micro 6.1**, installs necessary system packages, and bootstraps a single-node **RKE2 Kubernetes** cluster.

## 🧱 Details:

- Provisions an EC2 instance on AWS with the following specs:
  - SLE Micro 6.1 AMI (HVM)
  - Instance type (default: `g4dn.xlarge`)
  - Root volume (default: `300GB`)
  - Elastic IP assignment
- SSH key pair management (default: `create new` OR use existing)
- Remote provisioning using `remote-exec` to:
  - Installing basic utilities and packages.
  - Install the latest stable `rke2-server`.
  - Starting RKE2 server and download kubeconfig locally.
- Outputs:
  - EC2 public IP
  - `kubeconfig` content (base64-encoded)

## 📦 Requirements

- Terraform v1.5.0+
- AWS CLI configured with appropriate IAM credentials. (`AWS_REGION, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`)
- Let terraform generate SSH keys for accessing EC2 instance or use existing keypair.
- SLE Micro 6.1 AMI available in your AWS region.

## 🛠️ Usage

```hcl
module "rke2_node" {
  source = "./infrastructure"

  instance_type         = var.instance_type
  use_existing_ssh_key  = false

}
```
