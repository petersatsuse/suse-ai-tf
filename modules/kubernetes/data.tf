# Ensure kubeconfig is ready before proceeding
resource "null_resource" "validate_kubernetes_connection" {
  # The reference to the signal file creates an implicit dependency
  triggers = {
    signal_file = var.kubeconfig_ready_signal
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating Kubernetes connection..."
      kubectl --kubeconfig=${var.kubeconfig_path} get nodes || (echo "Failed to connect to Kubernetes cluster" && exit 1)
    EOT
  }
}
