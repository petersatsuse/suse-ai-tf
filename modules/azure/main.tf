# Generate a SSH KEY PAIR
resource "tls_private_key" "ssh_keypair" {
  count     = var.use_existing_ssh_public_key ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local
resource "local_file" "private_key" {
  count           = var.use_existing_ssh_public_key ? 0 : 1
  content         = one(tls_private_key.ssh_keypair[*]).private_key_openssh
  filename        = "${path.module}/tf-ssh-private-key"
  file_permission = "0600"
}

# Save public key to local
resource "local_file" "public_key" {
  count           = var.use_existing_ssh_public_key ? 0 : 1
  content         = tls_private_key.ssh_keypair[0].public_key_openssh
  filename        = "${path.module}/tf-ssh-public_key.pub"
  file_permission = "0644"
}

# Upload Public key to Azure
resource "azurerm_ssh_public_key" "generated_vm_key_azure_resource" {
  name                = "${var.instance_prefix}-vm-key"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  public_key          = var.use_existing_ssh_public_key ? data.local_file.ssh_public_key[0].content : tls_private_key.ssh_keypair[0].public_key_openssh
}

# Create a random resource group name
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.region
  name     = random_pet.rg_name.id
  tags     = var.common_tags
}

# Create virtual network
resource "azurerm_virtual_network" "test_vpc" {
  name                = "${var.instance_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.common_tags
}

# Create subnet
resource "azurerm_subnet" "test_subnet" {
  name                 = "${var.instance_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.test_vpc.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "test_public_ip" {
  name                = "${var.instance_prefix}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.common_tags
}

# Create Network Security Group
resource "azurerm_network_security_group" "test_nsg" {
  name                = "${var.instance_prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.common_tags
}

# Create Network Security rules with help of locals.tf file
resource "azurerm_network_security_rule" "test_rules" {
  for_each                    = local.nsgrules
  name                        = each.key
  direction                   = each.value.direction
  access                      = each.value.access
  priority                    = each.value.priority
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.test_nsg.name
}

# Create network interface
resource "azurerm_network_interface" "test_nic" {
  name                = "${var.instance_prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.test_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.test_public_ip.id
  }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "RSG" {
  network_interface_id      = azurerm_network_interface.test_nic.id
  network_security_group_id = azurerm_network_security_group.test_nsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "sle_micro_6" {
  name                  = "${var.instance_prefix}-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.test_nic.id]
  size                  = var.instance_type
  tags                  = var.common_tags

  os_disk {
    name                 = "${var.instance_prefix}-OsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = "150"
  }

  source_image_reference {
    publisher = split(":", var.image)[0]
    offer     = split(":", var.image)[1]
    sku       = split(":", var.image)[2]
    version   = split(":", var.image)[3]
  }

  computer_name                   = "hostname"
  admin_username                  = var.ssh_user
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.ssh_user
    public_key = azurerm_ssh_public_key.generated_vm_key_azure_resource.public_key
  }
}

# Make sure we have the ipv4 endpoint
data "http" "my_public_ip" {
  url = "https://ipv4.icanhazip.com"
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
