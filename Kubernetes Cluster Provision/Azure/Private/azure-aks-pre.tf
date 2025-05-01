# 1. Specify the version of the AzureRM Provider to use
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.81.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
# Configuration options
  subscription_id = "1d791106-0fdb-45cd-9ed5-adac37d5bfd7"
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg_roup" {
  name     = "tf-test"
  location = "centralindia"
}

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

resource "azurerm_public_ip" "public_ip" {
  name                    = "my-public-ip"
  location                = azurerm_resource_group.rg_roup.location
  resource_group_name     = azurerm_resource_group.rg_roup.name
  allocation_method       = "Static"

  tags = {
    Environment = "Testing"
  }
}

data "azurerm_public_ip" "public_ip" {
  name                = azurerm_public_ip.public_ip.name
  resource_group_name = azurerm_public_ip.public_ip.resource_group_name
}

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

resource "azurerm_virtual_machine" "jumphost" {
  name                    = "tf-jumphost"
  location                = azurerm_resource_group.rg_roup.location
  resource_group_name     = azurerm_resource_group.rg_roup.name
  vm_size                 = "Standard_B2s"
  network_interface_ids   = [ azurerm_network_interface.net_card.id ]


  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_profile {
    computer_name   = "hostname"
    admin_username  = "santosh"
    admin_password  = "santosh@1234"
  }

  storage_os_disk {
    name              = "my_os_disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = "64"
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
      "sudo cp ./kubectl /usr/bin/kubectl",
      "sudo mv ./kubectl /usr/local/bin/kubectl",
      "sudo apt update",
      "sudo apt install -y apt-transport-https ca-certificates curl software-properties-common",
      "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
      "echo \"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu  focal stable\" | sudo tee /etc/apt/sources.list.d/docker.list",
      "sudo apt update",
      "sudo apt install docker-ce -y",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo apt update",
      "sudo apt install ca-certificates curl apt-transport-https lsb-release gnupg", "curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null",
      "AZ_REPO=$(lsb_release -cs)",
      "echo \"deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main\" | sudo tee /etc/apt/sources.list.d/azure-cli.list",
      "sudo apt update",
      "sudo apt install azure-cli",
      "az --version",
      ]

  connection {
    type = "ssh"
    user = "santosh"
    password = "santosh@1234"
    host = data.azurerm_public_ip.public_ip.ip_address
  }
  }                     
}

