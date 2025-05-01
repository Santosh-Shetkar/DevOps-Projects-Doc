# Step-by-Step Guide: Deploy Azure Infrastructure with Terraform
## hi
This guide outlines how to deploy the foundational infrastructure for a **private Azure Kubernetes Service (AKS) cluster** using Terraform. The infrastructure consists of a **Resource Group**, **Virtual Network**, **Subnets**, **Public IP**, **Network Interface**, and a **Jump Host VM** to facilitate secure SSH access.

---

## Terraform Configuration Breakdown

The following Terraform configuration creates the necessary infrastructure on Microsoft Azure for deploying the private AKS cluster and a jump host for accessing it.

### Step 1: Define the Provider

The configuration starts by specifying the **AzureRM provider** with the version `3.81.0` for Azure resources management.

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.81.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "1d791106-0fdb-45cd-9ed5-adac37d5bfd7"
  features {}
}

- Provider: Configures the Azure provider with the subscription ID to interact with Azure resources.
- Features: Specifies the default features for the Azure provider.

### Step 2: Create Resource Group
The next step is to create an Azure Resource Group, which will hold all other resources.
```hcl
resource "azurerm_resource_group" "rg_roup" {
  name     = "tf-test"
  location = "centralindia"
}
```
- Resource Group: tf-test will be created in the centralindia region.
### Step 3: Create Virtual Network and Subnets
A Virtual Network (VNet) with two subnets is created for the AKS cluster and the jump host.
```hcl
resource "azurerm_virtual_network" "my_vnet" {
  name                = "tf-vnet"
  location            = azurerm_resource_group.rg_roup.location
  resource_group_name = azurerm_resource_group.rg_roup.name
  address_space       = ["10.1.0.0/26", "10.2.0.0/29"]

  tags = {
    Environment = "Testing"
  }
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "tf-aks"
  resource_group_name  = azurerm_resource_group.rg_roup.name
  virtual_network_name = azurerm_virtual_network.my_vnet.name
  address_prefixes     = ["10.1.0.0/26"]
}

resource "azurerm_subnet" "jumphost_subnet" {
  name                 = "tf-jumphost"
  resource_group_name  = azurerm_resource_group.rg_roup.name
  virtual_network_name = azurerm_virtual_network.my_vnet.name
  address_prefixes     = ["10.2.0.0/29"]
}
```
- Vnet: tf-vnet created with two address spaces: 10.1.0.0/26 (for AKS) and 10.2.0.0/29 (for jump host).

- Subnets:
    - tf-aks for the AKS cluster.
    - tf-jumphost for the jump host.

Step 4: Public IP for Jump Host
A static public IP is created for the jump host VM, allowing external access.
```hcl
resource "azurerm_public_ip" "public_ip" {
  name              = "my-public-ip"
  location          = azurerm_resource_group.rg_roup.location
  resource_group_name = azurerm_resource_group.rg_roup.name
  allocation_method = "Static"

  tags = {
    Environment = "Testing"
  }
}
```

Step 5: Network Interface
A network interface (NIC) is configured for the jump host, with the public IP attached.

```hcl
resource "azurerm_network_interface" "net_card" {
  name                = "tf-jumphost-nic"
  location            = azurerm_resource_group.rg_roup.location
  resource_group_name = azurerm_resource_group.rg_roup.name

  ip_configuration {
    name                          = "tf-jumphost-ip"
    subnet_id                     = azurerm_subnet.jumphost_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}
```

Step 6: Network Security Group (NSG)
A Network Security Group (NSG) is created to allow inbound SSH traffic (port 22) to the jump host.

```hcl
resource "azurerm_network_security_group" "nsg" {
  name                = "ssh_nsg"
  location            = azurerm_resource_group.rg_roup.location
  resource_group_name = azurerm_resource_group.rg_roup.name

  security_rule {
    name                       = "allow_ssh_sg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.net_card.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
```
Step 7: Jump Host VM
A Ubuntu-based virtual machine (VM) is deployed as a jump host. This VM is configured with a size (Standard_B2s), operating system, and network interface.

```hcl
resource "azurerm_virtual_machine" "jumphost" {
  name                  = "tf-jumphost"
  location              = azurerm_resource_group.rg_roup.location
  resource_group_name   = azurerm_resource_group.rg_roup.name
  vm_size               = "Standard_B2s"
  network_interface_ids = [azurerm_network_interface.net_card.id]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "santosh"
    admin_password = "santosh@1234"
  }

  storage_os_disk {
    name              = "my_os_disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 64
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    Environment = "Testing"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.28.8/bin/linux/amd64/kubectl",
      "sudo chmod +x ./kubectl",
      "sudo mv ./kubectl /usr/local/bin/kubectl",
      "sudo apt update",
      "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu focal stable\" | sudo tee /etc/apt/sources.list.d/docker.list",
      "sudo apt update",
      "sudo apt install -y docker-ce",
      "sudo systemctl enable --now docker",
      "curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null",
      "AZ_REPO=$(lsb_release -cs)",
      "echo \"deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main\" | sudo tee /etc/apt/sources.list.d/azure-cli.list",
      "sudo apt update",
      "sudo apt install -y azure-cli",
      "az --version"
    ]
    connection {
      type     = "ssh"
      user     = "santosh"
      password = "santosh@1234"
      host     = data.azurerm_public_ip.public_ip.ip_address
    }
  }
}
```

- VM: tf-jumphost using Ubuntu 22.04 LTS.
- Provisioner: Installs kubectl, Docker, and Azure CLI on the jump host.

### Running the Terraform Configuration
Prerequisites
Install Terraform.

Install Azure CLI and authenticate (az login).

Step 1: Initialize
```
terraform init
```

Step 2: Plan
```
terraform plan
```

Step 3: Apply
```
terraform apply
```

Type yes when prompted to confirm.

Step 4: Verify
- In the Azure portal, confirm the tf-test resource group and its resources.
- SSH into the jump host:
ssh santosh@<Public_IP>

Now after accessing the jump server setup AKS cluster by following below instructions

## Terraform AKS Cluster Deployment Guide

This guide explains how to configure and deploy an Amazon AKS (Azure Kubernetes Service) cluster using Terraform. All cluster-specific variables are managed via the aks-vars.yml file, and the infrastructure is provisioned using the azure-aks.tf configuration.

📁 File Structure

├── aks-vars.yml    # Cluster configuration variables

└── azure-aks.tf      # Terraform module and resource definitions

✍️ Step 1: Configure aks-vars.yml

Populate the following file with your desired cluster settings

🚀 Step 2: Deploy the AKS Cluster

From within the jump host (or your local environment if configured):

Initialize Terraform

```
terraform init
```
Apply the configuration
```
terraform apply -var-file=aks-vars.yml
```

Review the plan and confirm to proceed.