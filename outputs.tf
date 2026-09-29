# outputs.tf
# ----------------------------------------------------------------------------
# WHAT THIS FILE DOES: after `terraform apply` finishes, Terraform will
# print these values in your terminal — saves you from having to go dig
# through the Azure Portal just to find an IP address.
# You can also see these again any time later by typing: terraform output
# ----------------------------------------------------------------------------

output "dc01_public_ip" {
  description = "The address you RDP into for the Domain Controller."
  value       = azurerm_public_ip.dc01.ip_address
}

output "target_public_ip" {
  description = "The address you RDP into for the Test Machine."
  value       = azurerm_public_ip.target.ip_address
}

output "splunk_public_ip" {
  description = "The address you SSH into (and browse to on port 8000) for Splunk."
  value       = azurerm_public_ip.splunk.ip_address
}

output "dc01_private_ip" {
  description = "The Domain Controller's address inside the private network (used when configuring DNS/LDAP)."
  value       = azurerm_network_interface.dc01.private_ip_address
}

output "target_private_ip" {
  value = azurerm_network_interface.target.private_ip_address
}

output "splunk_private_ip" {
  description = "The Splunk server's private address (used when pointing forwarders at it)."
  value       = azurerm_network_interface.splunk.private_ip_address
}
