
#Generate a SSH KEY PAIR:
resource "tls_private_key" "ssh_keypair" {
  count     = var.use_existing_ssh_public_key ? 0 : 1
  algorithm = "ED25519"
}

#Save private key to local:
resource "local_file" "private_key" {
  count           = var.use_existing_ssh_public_key ? 0 : 1
  content         = tls_private_key.ssh_keypair[0].private_key_openssh
  filename        = "${path.module}/tf-ssh-private_key"
  file_permission = "0600"
}

#Save public key to local:
resource "local_file" "public_key" {
  count           = var.use_existing_ssh_public_key ? 0 : 1
  content         = tls_private_key.ssh_keypair[0].public_key_openssh
  filename        = "${path.module}/tf-ssh_public_key.pub"
  file_permission = "0644"
}

#Upload Public key to AWS:
resource "aws_key_pair" "deployer" {
  key_name   = "ssh-key"
  public_key = var.use_existing_ssh_public_key ? data.local_file.ssh_public_key[0].content : tls_private_key.ssh_keypair[0].public_key_openssh
}

#AWS_KEY_PAIR
#resource "aws_key_pair" "deployer" {
#  key_name   = "test-key"
#  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOY+hXbf+XLtd1rwdZb4qPDrwADsegng1nk4ICe+xr9L devendrakulkarni@Devendras-MacBook-Pro.local"
#}


# VPC
resource "aws_vpc" "test_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "test-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.test_vpc.id

  tags = {
    Name = "test-igw"
  }
}
#
# Route Table
resource "aws_route_table" "test_rt" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "test-rt"
  }
}

# Subnet
resource "aws_subnet" "test_subnet" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags = {
    Name = "test-subnet"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.test_subnet.id
  route_table_id = aws_route_table.test_rt.id
}

# Security Group allowing SSH
resource "aws_security_group" "ssh" {
  name        = "allow_ssh"
  description = "Allow SSH"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh-access"
  }
}

resource "aws_eip" "ec2_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.instance_prefix}-eip"
  }
}

resource "aws_instance" "sle_micro_6" {
  depends_on    = [aws_key_pair.deployer]
  ami           = data.aws_ami.suse_sle_micro6.id
  instance_type = var.instance_type

  tags = {
    Name = "${var.instance_prefix}-suse-ai-instance"
  }

  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.test_subnet.id
  vpc_security_group_ids = [aws_security_group.ssh.id]

  root_block_device {
    volume_size = 150 # Specify the desired volume size in GiB
  }

  provisioner "remote-exec" {
    inline = [
      "sudo transactional-update register -r ${var.registration_code}",
      "sudo transactional-update --continue run bash -c 'zypper install -y curl && zypper ar https://download.nvidia.com/suse/sle15sp6/ nvidia-sle15sp6-main && zypper --gpg-auto-import-keys refresh && zypper install -y --auto-agree-with-licenses nvidia-open-driver-G06-signed-kmp'",
      "sudo transactional-update --continue run zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G06=550.100",
      "sudo reboot"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
      host        = self.public_ip
    }
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.sle_micro_6.id
  allocation_id = aws_eip.ec2_eip.id
}

resource "null_resource" "post_reboot" {
  depends_on = [aws_instance.sle_micro_6]

  provisioner "remote-exec" {
    inline = [
      "echo 'Reconnected after reboot'",
      "echo 'Creating the RKE2 config file...'",
      "sudo mkdir -p /etc/rancher/rke2/ && sudo tee /etc/rancher/rke2/config.yaml > /dev/null <<EOF",
      "tls-san:",
      "  - ${aws_eip.ec2_eip.public_ip}",
      "EOF",
      "sudo curl -sfL https://get.rke2.io |sudo sh -",
      "sudo systemctl enable --now rke2-server",
      "sudo echo 'Waiting for RKE2-server to be ready...'",
      "while ! sudo systemctl is-active --quiet rke2-server; do echo 'Waiting for RKE2 to be active...'; sleep 10; done",
      "echo 'RKE2 is active and up. Setting KUBECONFIG and applying localpath provisioner.'",
      "sudo sh -c 'export PATH=$PATH:/opt/rke2/bin:/var/lib/rancher/rke2/bin && export KUBECONFIG=/etc/rancher/rke2/rke2.yaml && /var/lib/rancher/rke2/bin/kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml'"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
      host        = aws_eip.ec2_eip.public_ip
    }
  }
}

resource "null_resource" "download_kubeconfig" {
  depends_on = [null_resource.post_reboot]
  provisioner "remote-exec" {
    inline = [
      "sudo cp /etc/rancher/rke2/rke2.yaml /tmp/rke2.yaml",
      "sudo chown ec2-user:ec2-user /tmp/rke2.yaml",
      "sudo sed -i 's/127.0.0.1/${aws_eip.ec2_eip.public_ip}/g' /tmp/rke2.yaml"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
      host        = aws_eip.ec2_eip.public_ip
    }
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${path.module}/tf-ssh-private_key ec2-user@${aws_eip.ec2_eip.public_ip}:/tmp/rke2.yaml ./kubeconfig-rke2.yaml"
  }
}

resource "null_resource" "k8s_cleanup" {
  depends_on = [aws_eip_association.eip_assoc, null_resource.download_kubeconfig]
}

## Add the namespace for deploying SUSE AI Stack:

resource "kubernetes_namespace" "suse_ai_ns" {
  provider   = kubernetes.k8s
  depends_on = [aws_eip_association.eip_assoc, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, null_resource.k8s_cleanup]
  metadata {
    name = var.suse_ai_namespace
  }
}

## Add the secret for accessing the application-collection registry:

resource "kubernetes_secret" "suse-appco-registry" {
  provider   = kubernetes.k8s
  depends_on = [kubernetes_namespace.suse_ai_ns, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc, null_resource.k8s_cleanup]
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

  depends_on = [kubernetes_secret.suse-appco-registry, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc, null_resource.k8s_cleanup]

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

  depends_on = [kubernetes_secret.suse-appco-registry, aws_internet_gateway.igw, aws_route_table.test_rt, aws_route_table_association.public_assoc, aws_vpc.test_vpc, aws_eip_association.eip_assoc, null_resource.k8s_cleanup]

  values = [file("${path.module}/nvidia-gpu-operator-values.yaml")]

}


