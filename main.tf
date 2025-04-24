
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

  provisioner "remote-exec" {
    inline = [
      "sudo transactional-update register -r ${var.registration_code}"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = var.use_existing_ssh_public_key ? data.local_file.ssh_private_key[0].content : tls_private_key.ssh_keypair[0].private_key_openssh
      host        = aws_eip.ec2_eip.public_ip
    }
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.sle_micro_6.id
  allocation_id = aws_eip.ec2_eip.id
}
