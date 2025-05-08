# Terraform Kubernetes SUSE AI Stack Deployment

This Terraform module connects to an existing Kubernetes cluster (such as RKE2 on SLE Micro 6.1) using a provided `kubeconfig` file and deploys the full **SUSE AI Stack**. This includes:

## 🧱 Details:
- Consume existing clusters kubeconfig.
- Setting up namespaces.
- Setting up Image pull secrets for the Rancher Application Collection Registry.
- Installation of **cert-manager** via Helm.
- Installation of **NVIDIA gpu-operator** via Helm.
- Deployment of SUSE AI components via Helm:
  - **Milvus** (vector database)
  - **Ollama** (LLM runtime)
  - **Open WebUI** (chat-style interface)

## 📦 Requirements

- Terraform v1.5.0+
- Helm provider
- Kubernetes provider
- Base64-encoded kubeconfig (e.g., output from EC2 module)

## 🔧 Usage

```hcl
module "suse_ai_stack" {
  source = "./kubernetes"

  kubeconfig_base64     = module.rke2_node.kubeconfig_base64
  registry_server       = "registry.example.com"
  registry_username     = "myuser@suse.com"
  registry_password     = "TOKEN/PASSWORD HERE"
}
