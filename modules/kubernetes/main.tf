## Add the namespace for deploying SUSE AI Stack:
resource "kubernetes_namespace" "suse_ai_ns" {
  depends_on = [null_resource.validate_kubernetes_connection]
  metadata {
    name = var.suse_ai_namespace
  }
}

## Add the secret for accessing the application-collection registry:
resource "kubernetes_secret" "suse-appco-registry" {
  depends_on = [kubernetes_namespace.suse_ai_ns]
  metadata {
    name      = var.registry_secretname
    namespace = var.suse_ai_namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.registry_name}" = {
          username = var.registry_username,
          password = var.registry_password,
          auth     = base64encode("${var.registry_username}:${var.registry_password}")
        }
      }
    })
  }
}

## Add NVIDIA-GPU-OPERATOR using helm:
resource "helm_release" "nvidia_gpu_operator" {
  name       = "nvidia-gpu-operator"
  namespace  = var.gpu_operator_ns
  repository = "https://helm.ngc.nvidia.com/nvidia"
  chart      = "gpu-operator"

  create_namespace = true
  depends_on       = [null_resource.validate_kubernetes_connection]

  values = [file("${path.module}/nvidia-gpu-operator-values.yaml")]
}

## Add cert-manager using helm:
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = var.suse_ai_namespace
  repository = "oci://${var.registry_name}/charts"
  chart      = "cert-manager"

  create_namespace = true
  depends_on       = [kubernetes_secret.suse-appco-registry, helm_release.nvidia_gpu_operator]

  set {
    name  = "crds.enabled"
    value = "true"
  }

  set {
    name  = "global.imagePullSecrets[0].name"
    value = kubernetes_secret.suse-appco-registry.metadata[0].name
  }
}

## Add label to node for GPU assignment:
resource "null_resource" "label_node" {
  depends_on = [null_resource.validate_kubernetes_connection]

  provisioner "remote-exec" {
    inline = [
      "NODE_NAME=$(sudo /var/lib/rancher/rke2/bin/kubectl get nodes --kubeconfig /etc/rancher/rke2/rke2.yaml -o jsonpath='{.items[0].metadata.name}') && sudo /var/lib/rancher/rke2/bin/kubectl label node $NODE_NAME accelerator=nvidia-gpu --kubeconfig /etc/rancher/rke2/rke2.yaml --overwrite"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.ssh_private_key_content
      host        = var.ec2_public_ip
    }
  }
}

# Patch RKE-Ingress controller to allow hostNetwork so we can access SUSE AI on public IP:
resource "null_resource" "patch_ingress_hostnetwork" {
  depends_on = [null_resource.label_node]

  provisioner "remote-exec" {
    inline = [
      "sudo /var/lib/rancher/rke2/bin/kubectl get pods -A --kubeconfig /etc/rancher/rke2/rke2.yaml",
      "sudo sleep 90",
      "sudo /var/lib/rancher/rke2/bin/kubectl get pods -A --kubeconfig /etc/rancher/rke2/rke2.yaml",
      "sudo /var/lib/rancher/rke2/bin/kubectl patch daemonset --kubeconfig /etc/rancher/rke2/rke2.yaml rke2-ingress-nginx-controller -n kube-system --type='merge' -p '{\"spec\":{\"template\":{\"spec\":{\"hostNetwork\":true}}}}'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.ssh_private_key_content
      host        = var.ec2_public_ip
    }
  }
}

## Adding Milvus using helm:
resource "helm_release" "milvus" {
  name             = "milvus"
  namespace        = var.suse_ai_namespace
  repository       = "oci://${var.registry_name}/charts"
  chart            = "milvus"
  version          = "4.2.2"
  create_namespace = true
  depends_on       = [kubernetes_secret.suse-appco-registry, helm_release.nvidia_gpu_operator]

  values = [file("${path.module}/milvus-overrides.yaml")]
}

## Adding Ollama using helm:
resource "helm_release" "ollama" {
  name             = "ollama"
  namespace        = var.suse_ai_namespace
  repository       = "oci://${var.registry_name}/charts"
  chart            = "ollama"
  create_namespace = true
  timeout          = 900
  depends_on       = [helm_release.milvus, helm_release.nvidia_gpu_operator]

  values = [file("${path.module}/ollama-overrides.yaml")]
}

## Adding Open-WebUI using helm:
resource "helm_release" "open_webui" {
  name             = "open-webui"
  namespace        = var.suse_ai_namespace
  repository       = "oci://${var.registry_name}/charts"
  chart            = "open-webui"
  version          = "3.3.2"
  create_namespace = true
  depends_on       = [helm_release.milvus, helm_release.ollama]

  values = [file("${path.module}/openwebui-overrides.yaml")]
}
