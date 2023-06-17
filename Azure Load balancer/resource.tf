resource "azurerm_resource_group" "loadbtest" {
  name     = "load_balancer"
  location = "West Europe"
}

resource "azurerm_availability_set" "avabilityzone" {
  name                = "lb-aset"
  location            = azurerm_resource_group.loadbtest.location
  resource_group_name = azurerm_resource_group.loadbtest.name

  tags = {
    environment = "Production"
  }
  depends_on = [azurerm_resource_group.loadbtest]
}

resource "azurerm_virtual_network" "lbvnet" {
  name                = "virtualnet_lb"
  location            = azurerm_resource_group.loadbtest.location
  resource_group_name = azurerm_resource_group.loadbtest.name
  address_space       = ["10.0.0.0/16"]
  depends_on          = [azurerm_resource_group.loadbtest]
}

resource "azurerm_subnet" "subnetabc" {
  name                 = "lbSubnetA"
  resource_group_name  = azurerm_resource_group.loadbtest.name
  virtual_network_name = azurerm_virtual_network.lbvnet.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [azurerm_virtual_network.lbvnet]
}

//This is a NIC for VM A

resource "azurerm_network_interface" "nicforA" {
  name                = "networkicA"
  location            = azurerm_resource_group.loadbtest.location
  resource_group_name = azurerm_resource_group.loadbtest.name

  ip_configuration {
    name                          = "internalA"
    subnet_id                     = azurerm_subnet.subnetabc.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [azurerm_subnet.subnetabc]
}

resource "azurerm_network_security_group" "securitygp" {
  name                = "security-nsg"
  location            = azurerm_resource_group.loadbtest.location
  resource_group_name = azurerm_resource_group.loadbtest.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "secgpa" {
  subnet_id                 = azurerm_subnet.subnetabc.id
  network_security_group_id = azurerm_network_security_group.securitygp.id
}

//This is a NIC for VM B

resource "azurerm_network_interface" "nicforB" {
  name                = "networkicB"
  location            = azurerm_resource_group.loadbtest.location
  resource_group_name = azurerm_resource_group.loadbtest.name

  ip_configuration {
    name                          = "internalB"
    subnet_id                     = azurerm_subnet.subnetabc.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [azurerm_subnet.subnetabc]
}

//Here I am creating Virtual Machine A

resource "azurerm_linux_virtual_machine" "virtualmA" {
  name                            = "vmachineA"
  resource_group_name             = azurerm_resource_group.loadbtest.name
  location                        = azurerm_resource_group.loadbtest.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "Dipu$ingh123"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nicforA.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface.nicforA, azurerm_availability_set.avabilityzone]
}

//Here I am creating Virtual Machine B

resource "azurerm_linux_virtual_machine" "virtualmB" {
  name                            = "vmachineB"
  resource_group_name             = azurerm_resource_group.loadbtest.name
  location                        = azurerm_resource_group.loadbtest.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "Dipu$ingh123"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nicforB.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface.nicforB, azurerm_availability_set.avabilityzone]
}

# This virtual machine id for configuration other VM

resource "azurerm_public_ip" "mypubip" {
  name                = "mypubip"
  resource_group_name = azurerm_resource_group.loadbtest.name
  location            = azurerm_resource_group.loadbtest.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}


//This is a NIC for VM B
resource "azurerm_network_interface" "nicforC" {
  name                = "networkiC"
  location            = azurerm_resource_group.loadbtest.location
  resource_group_name = azurerm_resource_group.loadbtest.name

  ip_configuration {
    name                          = "internalB"
    subnet_id                     = azurerm_subnet.subnetabc.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mypubip.id
  }
  depends_on = [azurerm_subnet.subnetabc]
}



resource "azurerm_linux_virtual_machine" "virtualmC" {
  name                            = "vmachineC"
  resource_group_name             = azurerm_resource_group.loadbtest.name
  location                        = azurerm_resource_group.loadbtest.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "Dipu$ingh123"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nicforC.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  depends_on = [azurerm_network_interface.nicforC, azurerm_availability_set.avabilityzone]
}


# From Here I am implementing Load Balancer 

resource "azurerm_public_ip" "loadblpip" {
  name                = "pipPublicIPForLB"
  location            = azurerm_resource_group.loadbtest.location
  resource_group_name = azurerm_resource_group.loadbtest.name
  allocation_method   = "Static"
  sku = "Standard"
}


resource "azurerm_lb" "azloadbl" {
  name                = "yesTestLoadBalancer"
  location            = azurerm_resource_group.loadbtest.location
  resource_group_name = azurerm_resource_group.loadbtest.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.loadblpip.id
  }
  sku = "Standard"
  depends_on = [ azurerm_public_ip.loadblpip ]
}



resource "azurerm_lb_backend_address_pool" "backendpool" {
  loadbalancer_id = azurerm_lb.azloadbl.id
  name            = "AddressPooljia"
}

resource "azurerm_lb_backend_address_pool_address" "myvmA" {
  name                    = "myvmA"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
  virtual_network_id      = azurerm_virtual_network.lbvnet.id
  ip_address              = azurerm_network_interface.nicforA.private_ip_address
  depends_on              = [azurerm_lb_backend_address_pool.backendpool]
}

resource "azurerm_lb_backend_address_pool_address" "myvmB" {
  name                    = "myvmB"
  backend_address_pool_id = azurerm_lb_backend_address_pool.backendpool.id
  virtual_network_id      = azurerm_virtual_network.lbvnet.id
  ip_address              = azurerm_network_interface.nicforB.private_ip_address
  depends_on              = [azurerm_lb_backend_address_pool.backendpool]
}


//health Probe
resource "azurerm_lb_probe" "healthprob" {
  loadbalancer_id = azurerm_lb.azloadbl.id
  name            = "http"
  port            = 80
}

resource "azurerm_lb_rule" "loadlbrule" {
  loadbalancer_id                = azurerm_lb.azloadbl.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [ azurerm_lb_backend_address_pool.backendpool.id ]
  probe_id                       = azurerm_lb_probe.healthprob.id
}

output "pivateip1" {
  value = azurerm_network_interface.nicforA.private_ip_address
}

output "pivateip" {
  value = azurerm_network_interface.nicforB.private_ip_address
}