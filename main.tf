terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "3.0.0"
    }
  }
}

provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "sirirg" {
    name = "sirirg"
    location = "East US"
}

resource "azurerm_virtual_network" "sirivnet" {
    name = "sirivnet"
    resource_group_name = "sirirg"
    location = "East US"
    address_space = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "sirisubnet" {
    name = "sirisubnet"
    resource_group_name = "sirirg"
    virtual_network_name = "sirivnet"
    address_prefixes = ["10.1.1.0/24"]
}

resource "azurerm_public_ip" "siri_public_ip" {
    name = "siri_public_ip"
    resource_group_name = "sirirg"
    location = "East US"
    allocation_method = "Static"
}

resource "azurerm_network_interface" "sirinic" {
    name = "sirinic"
    location = "East US"
    resource_group_name = "sirirg"

    ip_configuration {
        name = "sirisubnet"
        subnet_id = azurerm_subnet.sirisubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.siri_public_ip.id
    }

    depends_on = [
        azurerm_virtual_network.sirivnet,
        azurerm_public_ip.siri_public_ip
    ]
}

resource "azurerm_windows_virtual_machine" "sirivm" {
    name  = "sirivm"
    resource_group_name = "sirirg"
    location = "East US"
    size = "Standard_D2s_v4"
    admin_username = "stestuser"
    admin_password = "siri@1234567"
    network_interface_ids = [
        azurerm_network_interface.sirinic.id,
    ]

    os_disk {
        caching    = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsserver"
        offer = "WindowsServer"
        sku = "2019-Datacenter"
        version = "latest"
    }

    depends_on = [
        azurerm_network_interface.sirinic
    ]
}

resource "azurerm_network_security_group" "siri_nsg" {
  name                = "siri_nsg"
  location            = "East US"
  resource_group_name = "sirirg"

# We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow_RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.sirisubnet.id
  network_security_group_id = azurerm_network_security_group.siri_nsg.id
  depends_on = [
    azurerm_network_security_group.siri_nsg
  ]
}