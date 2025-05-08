## Add the namespace for deploying SUSE AI Stack:

resource "kubernetes_namespace" "suse_ai_ns" {
  provider   = kubernetes.k8s
  depends_on = [null_resource.download_kubeconfig, aws_eip_association.eip_assoc, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc]
  metadata {
    name = var.suse_ai_namespace
  }
}

## Add the secret for accessing the application-collection registry:

resource "kubernetes_secret" "suse-appco-registry" {
  provider   = kubernetes.k8s
  depends_on = [null_resource.download_kubeconfig, kubernetes_namespace.suse_ai_ns, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc]
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


## Add cert-manager using helm:

resource "helm_release" "cert_manager" {
  provider   = helm
  name       = "cert-manager"
  namespace  = var.suse_ai_namespace
  repository = "oci://${var.registry_name}/charts"
  chart      = "cert-manager"

  create_namespace = true

  depends_on = [null_resource.download_kubeconfig, kubernetes_secret.suse-appco-registry, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc, helm_release.nvidia_gpu_operator]

  set {
    name  = "crds.enabled"
    value = "true"
  }

  set {
    name  = "global.imagePullSecrets[0].name"
    value = kubernetes_secret.suse-appco-registry.metadata[0].name
  }
}

## Add NVIDIA-GPU-OPERATOR using helm:

resource "helm_release" "nvidia_gpu_operator" {
  provider   = helm
  name       = "nvidia-gpu-operator"
  namespace  = var.gpu_operator_ns
  repository = "https://helm.ngc.nvidia.com/nvidia"
  chart      = "gpu-operator"

  create_namespace = true

  depends_on = [null_resource.download_kubeconfig, kubernetes_secret.suse-appco-registry, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc]

  values = [file("${path.module}/nvidia-gpu-operator-values.yaml")]

}

## Add label to node for GPU assignment:

resource "null_resource" "label_node" {
  depends_on = [null_resource.download_kubeconfig]

  provisioner "remote-exec" {
    inline = [
      "NODE_NAME=$(sudo /var/lib/rancher/rke2/bin/kubectl get nodes --kubeconfig /etc/rancher/rke2/rke2.yaml -o jsonpath='{.items[0].metadata.name}') && sudo /var/lib/rancher/rke2/bin/kubectl label node $NODE_NAME accelerator=nvidia-gpu --kubeconfig /etc/rancher/rke2/rke2.yaml --overwrite"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
      host        = aws_eip.ec2_eip.public_ip
    }
  }
}

# Patch RKE-Ingress controller to allow hostNetwork so we can access SUSE AI on public IP:

resource "null_resource" "patch_ingress_hostnetwork" {
  depends_on = [null_resource.download_kubeconfig, null_resource.label_node]

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
      private_key = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
      host        = aws_eip.ec2_eip.public_ip
    }
  }
}

## Adding SUSE AI Stack

## Adding Milvus using helm:

resource "helm_release" "milvus" {
  provider         = helm
  name             = "milvus"
  namespace        = var.suse_ai_namespace
  repository       = "oci://${var.registry_name}/charts"
  chart            = "milvus"
  version          = "4.2.2"
  create_namespace = true

  depends_on = [null_resource.download_kubeconfig, kubernetes_secret.suse-appco-registry, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc, helm_release.nvidia_gpu_operator]

  values = [file("${path.module}/milvus-overrides.yaml")]

}


## Adding Ollama using helm:

resource "helm_release" "ollama" {
  provider         = helm
  name             = "ollama"
  namespace        = var.suse_ai_namespace
  repository       = "oci://${var.registry_name}/charts"
  chart            = "ollama"
  create_namespace = true
  timeout          = 900

  depends_on = [null_resource.download_kubeconfig, kubernetes_secret.suse-appco-registry, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc, helm_release.milvus, helm_release.nvidia_gpu_operator]

  values = [file("${path.module}/ollama-overrides.yaml")]

}

## Adding Open-WebUI using helm:

resource "helm_release" "open_webui" {
  provider         = helm
  name             = "open-webui"
  namespace        = var.suse_ai_namespace
  repository       = "oci://${var.registry_name}/charts"
  chart            = "open-webui"
  version          = "3.3.2"
  create_namespace = true

  depends_on = [null_resource.download_kubeconfig, kubernetes_secret.suse-appco-registry, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc, helm_release.milvus, helm_release.ollama, helm_release.nvidia_gpu_operator]

  values = [file("${path.module}/openwebui-overrides.yaml")]

}
