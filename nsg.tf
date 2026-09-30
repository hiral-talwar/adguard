# nsg.tf
# ----------------------------------------------------------------------------
# WHAT THIS FILE DOES: this is the firewall. An NSG (Network Security
# Group) is a list of rules saying exactly who is allowed to connect to
# your VMs, on which "door" (port), using which "language" (protocol).
# By default, Azure blocks EVERYTHING inbound — every rule below is you
# deliberately opening one specific, narrow door.
# ----------------------------------------------------------------------------

resource "azurerm_network_security_group" "lab" {
  name                = "nsg-${var.project_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Door #1: RDP (remote desktop, port 3389) — but ONLY from your own IP.
  # This is the door you personally walk through to see your Windows VMs'
  # screens. Locking it to your IP means nobody else on the internet can
  # even attempt to knock on this door.
  security_rule {
    name                       = "Allow-RDP-MyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_ip
    destination_address_prefix = "*"
  }

  # Door #2: SSH (command-line access, port 22) — same idea, but this is
  # the door you use to reach the Splunk (Ubuntu) VM's terminal.
  security_rule {
    name                       = "Allow-SSH-MyIP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ip
    destination_address_prefix = "*"
  }

  # Door #3: Splunk's web page (port 8000) — this is what lets your
  # browser load the Splunk dashboard. Locked to your IP too.
  security_rule {
    name                       = "Allow-Splunk-Web-MyIP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = var.allowed_ip
    destination_address_prefix = "*"
  }

  # Door #4: Splunk's "receiving" port (9997) — this is where the little
  # forwarder programs on your Windows VMs send their logs TO. This door
  # only needs to be open to traffic already INSIDE your private network
  # (the VNet), so instead of opening it to the whole internet, it's
  # scoped to "VirtualNetwork" — meaning only your own 3 VMs can use it.
  security_rule {
    name                       = "Allow-Splunk-Recv-VNetOnly"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9997"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # ----------------------------------------------------------------------
  # TWO TEMPORARY DOORS — left commented out (inactive) on purpose.
  # You will only open these for a few minutes at a time, later in the
  # project, to run specific tests. Instructions for exactly when are in
  # the main guide (Scenario 1 test, and the Shuffle/LDAP connection).
  #
  # HOW TO USE THEM: delete the "#" at the start of each line inside the
  # block you want to enable, save the file, run `terraform apply`, do
  # your test, then put the "#" symbols back and `terraform apply` again
  # to close the door. Keeping them here as text (instead of deleting
  # them) means your Git history shows exactly when you opened these and
  # for how long — which is good practice to point to later.
  # ----------------------------------------------------------------------

  # security_rule {
  #   name                       = "TEMP-Allow-RDP-Any"
  #   priority                   = 200
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "3389"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }

  # security_rule {
  #   name                       = "TEMP-Allow-LDAP-Shuffle"
  #   priority                   = 210
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "389"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = "*"
  # }

  tags = {
    project = "adguard"
  }
}

# This line is what actually "attaches" the firewall rules above to your
# subnet — without it, the NSG would exist but wouldn't actually be
# protecting anything.
resource "azurerm_subnet_network_security_group_association" "lab" {
  subnet_id                 = azurerm_subnet.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}
