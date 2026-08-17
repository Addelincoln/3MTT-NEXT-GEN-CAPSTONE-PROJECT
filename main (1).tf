terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "sme" {
  name     = var.resource_group_name
  location = var.location
}

# --- Networking -------------------------------------------------------

resource "azurerm_virtual_network" "sme" {
  name                = "vnet-sme-mvp"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.sme.location
  resource_group_name = azurerm_resource_group.sme.name
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.sme.name
  virtual_network_name = azurerm_virtual_network.sme.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.sme.location
  resource_group_name = azurerm_resource_group.sme.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # tighten to your office/VPN IP before go-live
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# Free Azure-provided DNS label: <dns_label>.<location>.cloudapp.azure.com
# No custom domain purchase or Azure DNS zone required for the MVP.
resource "azurerm_public_ip" "app" {
  name                = "pip-app"
  location            = azurerm_resource_group.sme.location
  resource_group_name = azurerm_resource_group.sme.name
  allocation_method   = "Static"
  sku                 = "Basic" # Basic SKU keeps this inside typical free-account usage
  domain_name_label   = var.dns_label
}

resource "azurerm_network_interface" "app" {
  name                = "nic-app"
  location            = azurerm_resource_group.sme.location
  resource_group_name = azurerm_resource_group.sme.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app.id
  }
}

# --- Compute ------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "app" {
  name                = "vm-sme-app"
  location            = azurerm_resource_group.sme.location
  resource_group_name = azurerm_resource_group.sme.name
  size                = var.vm_size # Standard_B1s -> free-account eligible
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.app.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # free-account eligible managed disk tier
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    app_repo_url = var.app_repo_url
  }))
}

# --- Optional custom domain (adds a small monthly cost, off by default) --

resource "azurerm_dns_zone" "custom" {
  count               = var.enable_custom_domain ? 1 : 0
  name                = var.custom_domain_name
  resource_group_name = azurerm_resource_group.sme.name
}

resource "azurerm_dns_a_record" "app" {
  count               = var.enable_custom_domain ? 1 : 0
  name                = "@"
  zone_name           = azurerm_dns_zone.custom[0].name
  resource_group_name = azurerm_resource_group.sme.name
  ttl                 = 3600
  records             = [azurerm_public_ip.app.ip_address]
}
