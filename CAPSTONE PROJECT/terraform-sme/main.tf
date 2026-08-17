terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Uses your existing `az login` session automatically - no separate
  # service principal credentials needed for this lab.
}

variable "my_ip" {
  description = "Your public IP address, used to restrict SSH access. Find it with (Invoke-RestMethod -Uri \"https://api.ipify.org\")"
  type        = string
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-sme-migration-tf"
  location = "indiasouthcentral" # eastus/eastus2/westus2/etc. were NotAvailableForSubscription on this Free Trial account
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-sme-tf"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-sme-app-se"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.my_ip}/32"
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

resource "azurerm_public_ip" "pip" {
  name                = "vm-sme-app-tf-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard" # Basic SKU was retired Sept 30, 2025 - Standard is required now
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-sme-app-tf"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "assoc" {
  network_interface_id     = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                   = "vm-sme-app-tf"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  size                   = "Standard_B1s" # confirmed available in indiasouthcentral for this subscription
  admin_username         = "azureuser"
  network_interface_ids  = [azurerm_network_interface.nic.id]
  custom_data            = filebase64("${path.module}/cloud-init.txt")

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(pathexpand("~/.ssh/vm_sme_key.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

output "public_ip_address" {
  value = azurerm_public_ip.pip.ip_address
}
