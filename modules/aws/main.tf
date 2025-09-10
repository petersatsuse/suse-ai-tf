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
  availability_zone       = data.aws_availability_zones.available.names[0]
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

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.sle_micro_6.id
  allocation_id = aws_eip.ec2_eip.id
}


# --- OS Update and Reboot Trigger ---
resource "null_resource" "post_reboot_update" {
  depends_on = [azurerm_linux_virtual_machine.sle_micro_6]

  triggers = {
    vm_id = azurerm_linux_virtual_machine.sle_micro_6.id
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
    host        = azurerm_public_ip.test_public_ip.ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Registering the system and configuring update channels...'",
      "sudo transactional-update register -r ${var.registration_code}",
      <<-EOF
      #!/bin/bash
      set -e
      set -x

      echo "--- Starting single transactional shell for all updates ---"

      sudo transactional-update shell <<'EOS'
        set -e
        set -x

        echo "1. Refreshing new repositories and installing utilities..."
        zypper --gpg-auto-import-keys refresh
        zypper in -y curl jq

        echo "2. Installing the base NVIDIA driver..."
        zypper in -y --auto-agree-with-licenses nvidia-open-driver-G06-signed-cuda-kmp-default

        echo "3. Determining the driver version..."
        VERSION=`rpm -qa --queryformat '%%{VERSION}\n' nvidia-open-driver-G06-signed-cuda-kmp-default | cut -d '_' -f1 | sort -u | tail -n 1`

        # Use curly braces for unambiguous variable expansion
        if [ -z "$${VERSION}" ]; then
          echo "FATAL: Could not determine NVIDIA driver version. Aborting."
          exit 1
        fi
        echo "#### Determined Version: $${VERSION} ####"

        echo "4. Installing version-specific NVIDIA utilities..."
        # Use curly braces and add quotes for safety
        zypper in -y --auto-agree-with-licenses "nvidia-compute-utils-G06=$${VERSION}"

        echo "5. Setting up environment files..."
        echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' > /etc/profile.d/rke2.sh
        echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin:/usr/local/nvidia/toolkit' > /etc/profile.d/nvidia-toolkit.sh
      EOS

      echo "--- Transactional updates applied. Issuing reboot. ---"
      sudo transactional-update reboot
    EOF
    ]
    on_failure = fail
  }
}

#--- Wait for VM to Reboot and Become Available ---
resource "null_resource" "wait_for_reboot_completion" {
  depends_on = [null_resource.post_reboot_update]

  triggers = {
    update_trigger_id = null_resource.post_reboot_update.id
  }

  provisioner "local-exec" {
    environment = {
      LOCAL_EXEC_SSH_USER            = var.ssh_user
      LOCAL_EXEC_SSH_HOST            = azurerm_public_ip.test_public_ip.ip_address
      LOCAL_EXEC_SSH_PRIVATE_KEY_PEM = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
    }

    command = <<EOT
      #!/bin/sh
      set -e

      echo "Executing with Trigger ID: ${self.triggers.update_trigger_id}"

      TMP_KEY_PATH=`mktemp`
      trap 'echo "Cleaning up temporary SSH key $${TMP_KEY_PATH}"; rm -f "$${TMP_KEY_PATH}"' EXIT

      printf '%s\n' "$${LOCAL_EXEC_SSH_PRIVATE_KEY_PEM}" > "$${TMP_KEY_PATH}"
      chmod 600 "$${TMP_KEY_PATH}"

      sleep 45

      ATTEMPTS=0
      MAX_ATTEMPTS=24
      WAIT_SECONDS=25

      echo "Polling VM SSH at $${LOCAL_EXEC_SSH_USER}@$${LOCAL_EXEC_SSH_HOST}..."

      while [ $${ATTEMPTS} -lt $${MAX_ATTEMPTS} ]; do
        ATTEMPTS=`expr $${ATTEMPTS} + 1`

        echo "Attempting to connect (Attempt $${ATTEMPTS}/$${MAX_ATTEMPTS})..."
        if ssh -i "$${TMP_KEY_PATH}" \
             -q \
             -o ConnectTimeout=10 \
             -o ConnectionAttempts=1 \
             -o BatchMode=yes \
             -o StrictHostKeyChecking=no \
             -o UserKnownHostsFile=/dev/null \
             "$${LOCAL_EXEC_SSH_USER}@$${LOCAL_EXEC_SSH_HOST}" \
             "echo 'SSH connection successful post-reboot'"; then
          echo "VM is back online after transactional update and reboot."
          exit 0
        fi
        echo "VM not yet reachable, waiting $${WAIT_SECONDS}s..."
        sleep "$${WAIT_SECONDS}"
      done

      echo "Error: VM ($${LOCAL_EXEC_SSH_HOST}) did not come back online after $${MAX_ATTEMPTS} attempts."
      exit 1
    EOT
  }
}
