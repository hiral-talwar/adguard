# vms.tf
# ----------------------------------------------------------------------------
# WHAT THIS FILE DOES: creates the actual 3 computers (VMs) for the project.
# For each one, we also create a "Public IP" (an internet-reachable address
# for it) and a "Network Interface" (NIC — think of this as the computer's
# network cable, plugging it into the VNet from network.tf).
#
# COST NOTE: Public IPs here use the "Standard" tier, which is the only
# tier Azure offers now — it bills a small amount (~$0.005/hour) even
# while the VM is turned off. This is the tradeoff for keeping your work
# safe by Stopping instead of Destroying — see the main guide.
# ----------------------------------------------------------------------------

# ============================= Domain Controller =============================
# This VM will become the "boss" server — running Windows Server and, once
# you configure it by hand in Part C, Active Directory Domain Services.

resource "azurerm_public_ip" "dc01" {
  name                = "pip-${var.project_prefix}-dc01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static" # "Static" means this IP won't change every time the VM restarts
  sku                 = "Standard"
}

resource "azurerm_network_interface" "dc01" {
  name                = "nic-${var.project_prefix}-dc01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.4" # fixed private address so other VMs can always find this one reliably
    public_ip_address_id          = azurerm_public_ip.dc01.id
  }
}

resource "azurerm_windows_virtual_machine" "dc01" {
  name                = "vm-${var.project_prefix}-dc01"
  computer_name       = "ADGUARD-DC01" # this is the name Windows itself will show, e.g. in Server Manager
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B1ms" # 2 vCPU / 4 GB RAM — cheapest size that still runs a Windows GUI smoothly
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.dc01.id,
  ]

  os_disk {
    caching               = "ReadWrite"
    storage_account_type = "StandardSSD_LRS" # "Standard SSD" — a cheaper disk tier than Premium, plenty fast for a lab
    # NOTE: no disk_size_gb set here on purpose. Windows Server 2022's
    # image ships with a 127 GB base disk, and Azure REJECTS any smaller
    # explicit size ("disk size X GB is smaller than the corresponding
    # disk in the VM image"). Leaving this unset lets Azure use the
    # image's required minimum automatically.
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  tags = {
    project = "adguard"
    role    = "domain-controller"
  }
}

# Auto-shutdown: a safety net. If you ever forget to manually Stop this
# VM, Azure will do it for you at the time you set, so you never wake up
# to a week of accidental billing.
#
# NOTE: this resource type isn't available in every region — it has its
# own, separate supported-region list from regular VM/network resources.
# That's why its location comes from var.shutdown_schedule_location
# instead of matching wherever your VMs actually live.
/*resource "azurerm_dev_test_global_vm_shutdown_schedule" "dc01" {
  virtual_machine_id    = azurerm_windows_virtual_machine.dc01.id
  location               = var.shutdown_schedule_location
  enabled                 = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone                = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }
}*/

# ================================ Test Machine =================================
# This VM plays the part of a normal "employee laptop" that gets joined to
# the domain in Part C.

resource "azurerm_public_ip" "target" {
  name                = "pip-${var.project_prefix}-target"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "target" {
  name                = "nic-${var.project_prefix}-target"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.5"
    public_ip_address_id          = azurerm_public_ip.target.id

    # NOTE: DNS for this VM gets pointed at the Domain Controller's
    # private IP inside the Azure Portal in Part C, right before you
    # join it to the domain — doing it there (rather than baking it in
    # here) matches the order of operations in the main guide.
  }
}

resource "azurerm_windows_virtual_machine" "target" {
  name                = "vm-${var.project_prefix}-target"
  computer_name       = "ADGUARD-TARGET"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B1ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.target.id,
  ]

  os_disk {
    caching               = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    # No disk_size_gb here either — same reason as the DC: Azure rejects
    # a size smaller than the Windows Server 2022 image's 127 GB base.
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  tags = {
    project = "adguard"
    role    = "test-machine"
  }
}

/*resource "azurerm_dev_test_global_vm_shutdown_schedule" "target" {
  virtual_machine_id    = azurerm_windows_virtual_machine.target.id
  location               = var.shutdown_schedule_location
  enabled                 = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone                = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }
}*/

# =================================== Splunk ====================================
# This VM runs Ubuntu (Linux) instead of Windows, because Splunk itself
# is the software doing the work here, and Linux is the lighter, cheaper,
# more common choice for running server software like this.

resource "azurerm_public_ip" "splunk" {
  name                = "pip-${var.project_prefix}-splunk"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "splunk" {
  name                = "nic-${var.project_prefix}-splunk"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.6"
    public_ip_address_id          = azurerm_public_ip.splunk.id
  }
}

resource "azurerm_linux_virtual_machine" "splunk" {
  name                = "vm-${var.project_prefix}-splunk"
  computer_name       = "adguard-splunk"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_B2ms" # 2 vCPU / 8 GB RAM — Splunk specifically asks for more RAM than the Windows boxes need
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.splunk.id,
  ]

  # Linux VMs here log in with an SSH KEY instead of a password — this is
  # what the `ssh-keygen` step earlier was for. More secure, and it's
  # the standard way Linux servers are accessed in the real world.
  #
  # NOTE: plain file("~/.ssh/id_rsa.pub") does NOT work reliably on
  # Windows — Terraform doesn't expand "~" into your home folder by
  # itself. pathexpand() is a Terraform built-in function that does that
  # expansion correctly on Windows, Mac, and Linux alike.
  disable_password_authentication = true
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }

  os_disk {
    caching               = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb          = 64 # a bit more than the ~30GB default image size, since Splunk's own data needs room too
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    project = "adguard"
    role    = "siem"
  }
}

/*resource "azurerm_dev_test_global_vm_shutdown_schedule" "splunk" {
  virtual_machine_id    = azurerm_linux_virtual_machine.splunk.id
  location               = var.shutdown_schedule_location
  enabled                 = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone                = var.auto_shutdown_timezone

  notification_settings {
    enabled = false
  }
}*/
