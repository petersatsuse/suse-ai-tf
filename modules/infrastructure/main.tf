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

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "${var.instance_prefix}-sg"
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
      "sudo transactional-update --continue run bash -c 'zypper install -y curl && zypper install -y jq && zypper ar https://download.nvidia.com/suse/sle15sp6/ nvidia-sle15sp6-main && zypper --gpg-auto-import-keys refresh && zypper install -y --auto-agree-with-licenses nvidia-open-driver-G06-signed-kmp'",
      "sudo transactional-update --continue run zypper install -y --auto-agree-with-licenses nvidia-compute-utils-G06=550.100",
      "sudo transactional-update --continue run bash -c 'echo KUBECONFIG=/etc/rancher/rke2/rke2.yaml >> /etc/profile && echo PATH=$PATH:/var/lib/rancher/rke2/bin:/usr/local/nvidia/toolkit >> /etc/profile'",
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
    command = "scp -o StrictHostKeyChecking=no -i ${path.module}/tf-ssh-private_key ec2-user@${aws_eip.ec2_eip.public_ip}:/tmp/rke2.yaml ${path.root}/modules/infrastructure/kubeconfig-rke2.yaml"
  }
}

# Add a validation step to ensure the kubeconfig is ready
resource "null_resource" "kubernetes_api_ready" {
  depends_on = [null_resource.download_kubeconfig]

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for the kubeconfig file to exist
      while [ ! -f "${path.module}/kubeconfig-rke2.yaml" ]; do
        echo "Waiting for kubeconfig file to be created..."
        sleep 5
      done
      
      # Try to reach the Kubernetes API
      MAX_RETRIES=30
      RETRY=0
      until kubectl --kubeconfig=${path.module}/kubeconfig-rke2.yaml cluster-info; do
        RETRY=$((RETRY+1))
        if [ $RETRY -eq $MAX_RETRIES ]; then
          echo "Failed to connect to Kubernetes API after $MAX_RETRIES attempts"
          exit 1
        fi
        echo "Waiting for Kubernetes API to become available... (attempt $RETRY/$MAX_RETRIES)"
        sleep 10
      done
      echo "Kubernetes API is ready"
    EOT
  }
}
