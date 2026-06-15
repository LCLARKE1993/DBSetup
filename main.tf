# 1. Specify the Required Providers and Versions
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Keeps it compatible with stable 3.x syntax
    }
  }
}

# 2. Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# 3. Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-datalake-prod-001"
  location = "East US"
  
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# 4. Create a Virtual Network and Subnet (Dependency for Secure Networking)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-datalake-prod-001"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "storage_subnet" {
  name                 = "snet-storage-prod-001"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  
  # Enables service endpoints so the storage account can securely talk to this subnet
  service_endpoints    = ["Microsoft.Storage"]
}

# 5. Create the Storage Account with ADLS Gen2 Capabilities
resource "azurerm_storage_account" "adls_storage" {
  name                     = "sadlakeprod001" # Must be globally unique, lowercase alphanumeric only
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Locally Redundant Storage (change to GRS for geo-redundancy)
  account_kind             = "StorageV2"

  # CRITICAL FOR ADLS GEN2: This enables the Hierarchical Namespace
  is_hns_enabled           = true

  # Security Best Practices
  enable_https_traffic_only       = true
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = true # Set to false if using Private Endpoints exclusively

  # Network Rules: Restrict access to our specific subnet and trusted IPs
  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.storage_subnet.id]
    bypass                     = ["AzureServices", "Logging", "Metrics"]
  }

  tags = {
    Environment = "Production"
  }
}

# 6. Create an ADLS Gen2 Filesystem (Container)
resource "azurerm_storage_data_lake_gen2_filesystem" "raw_zone" {
  name               = "raw"
  storage_account_id = azurerm_storage_account.adls_storage.id

  # Properties can be added here if you need to pre-configure directory-level ACLs
  

  depends_on = [
    azurerm_storage_account.adls_storage
  ]
}