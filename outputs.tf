output "public_ip_address" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.app.ip_address
}

output "free_dns_fqdn" {
  description = "Free Azure-provided hostname (no domain purchase needed)"
  value       = azurerm_public_ip.app.fqdn
}

output "custom_domain_nameservers" {
  description = "Point your registrar at these if enable_custom_domain = true"
  value       = var.enable_custom_domain ? azurerm_dns_zone.custom[0].name_servers : null
}

output "ssh_command" {
  description = "Quick SSH command to reach the VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.app.fqdn}"
}
