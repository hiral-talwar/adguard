# network.tf
# ----------------------------------------------------------------------------
# WHAT THIS FILE DOES: builds the "neighborhood" your VMs will live in —
# a Resource Group (a folder for everything), a Virtual Network (a private
# road system only your VMs can drive on), and a Subnet (one specific
# street within that road system).
# ----------------------------------------------------------------------------

# The Resource Group: think of this as a single folder that will contain
# EVERY resource this project creates. The big benefit: at the very end of
# the project, deleting this one folder deletes everything inside it —
# no chance of a forgotten, quietly-billing leftover piece.
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project = "adguard"
  }
}

# The Virtual Network (VNet): a private network that only your 3 VMs are
# part of. Anything inside this network can talk to anything else inside
# it, automatically — that's why your DC, target, and Splunk VMs will be
# able to ping each other without any extra setup.
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_prefix}"
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project = "adguard"
  }
}

# The Subnet: one slice of that private network. A /24 gives you 254
# usable addresses, which is far more than the 3 VMs need — plenty of
# room if you ever add a 4th machine later.
resource "azurerm_subnet" "lab" {
  name                 = "snet-lab"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}
