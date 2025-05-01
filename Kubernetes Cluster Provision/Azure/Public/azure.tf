# Specify the version of the AzureRM Provider to use
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.1.0"
    }
  }
}

locals {
  cluster_config    = yamldecode(file("vars.yml"))
  platform_nodes    = local.cluster_config.platform_nodes
  compute_nodes     = local.cluster_config.compute_nodes
  vectordb_nodes    = local.cluster_config.vectordb_nodes  
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
# Configuration options
  subscription_id = local.cluster_config.azure_subscription_id
  features {}
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.cluster_config.cluster_name
  location            = local.cluster_config.resource_group_location
  resource_group_name = local.cluster_config.resource_group_name
  kubernetes_version  = local.cluster_config.kubernetes_version
  dns_prefix          = "my-test-domain"
  sku_tier = local.cluster_config.aks_pricing_tier

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
    network_policy = "calico"
  }

  default_node_pool {
    name            = "compute"
    vm_size         = local.compute_nodes.instance_type
    
    node_labels = {
      "santosh.ai/node-pool" = "compute"
    }
    
    auto_scaling_enabled = true
    max_count          = local.compute_nodes.max_count
    min_count          = local.compute_nodes.min_count
    node_count         = local.compute_nodes.min_count
    os_disk_size_gb    = local.compute_nodes.os_disk_size
    zones              = [ 1 , 2 ]

    max_pods = "110"
  }

  tags = {
    unique-id = "santosh-${local.cluster_config.random_value}"
    URL       = "my-test-domain"
  }

}

resource "azurerm_kubernetes_cluster_node_pool" "nodepool_platform" {
  name                  = "platform"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = local.platform_nodes.instance_type

  node_labels = {
    "santosh.ai/node-pool" = "platform"
  }
  
  node_taints = ["santosh.ai/node-pool=platform:NoSchedule"]

  auto_scaling_enabled = true
  max_count         = local.platform_nodes.max_count
  min_count         = local.platform_nodes.min_count
  node_count        = local.platform_nodes.min_count
  os_disk_size_gb   = local.platform_nodes.os_disk_size
  zones             = [ 1 , 2 ]

  max_pods = "110"

  tags = {
    unique-id = "santosh-${local.cluster_config.random_value}"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "nodepool_vectordb" {
  name                  = "vectordb"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = local.vectordb_nodes.instance_type

  node_labels = {
    "santosh.ai/node-pool" = "vectordb"
  }
  
  node_taints = ["santosh.ai/node-pool=vectordb:NoSchedule"]

  auto_scaling_enabled = true
  max_count         = local.vectordb_nodes.max_count
  min_count         = local.vectordb_nodes.min_count
  node_count        = local.vectordb_nodes.min_count
  os_disk_size_gb   = local.vectordb_nodes.os_disk_size
  zones             = [ 1 , 2 ]

  max_pods = "110"

  tags = {
    unique-id = "santosh-${local.cluster_config.random_value}"
  }
}

