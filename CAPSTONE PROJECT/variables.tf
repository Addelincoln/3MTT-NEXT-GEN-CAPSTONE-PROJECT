variable "resource_group_name" {
  description = "Name of the Azure resource group for this project"
  type        = string
  default     = "rg-sme-lamp-mvp"
}

variable "location" {
  description = "Azure region (choose one close to your users, e.g. westeurope, uksouth, southafricanorth)"
  type        = string
  default     = "westeurope"
}

variable "vm_size" {
  description = "VM size. Standard_B1s is covered by the Azure free account (750 hrs/month)."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Linux admin username for the VM"
  type        = string
  default     = "smeadmin"
}

variable "ssh_public_key_path" {
  description = "Path to your local SSH public key (~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "dns_label" {
  description = "Free Azure-provided DNS label. Final address: <dns_label>.<location>.cloudapp.azure.com"
  type        = string
  default     = "sme-app-mvp"
}

variable "enable_custom_domain" {
  description = "Set true to also provision an Azure DNS zone for a custom domain (small monthly cost, not covered by free tier)"
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "Custom domain name, only used if enable_custom_domain = true (e.g. myshop.ng)"
  type        = string
  default     = ""
}

variable "app_repo_url" {
  description = "Git URL of the LAMP application to deploy. Leave blank to deploy the sample placeholder site."
  type        = string
  default     = ""
}
