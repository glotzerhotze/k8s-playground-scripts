# Create a virtual network for the KIND VM to live in
resource "azurerm_virtual_network" "kind-playground" {
  name                = "kind-playground"
  resource_group_name = azurerm_resource_group.kind-playground.name
  location            = azurerm_resource_group.kind-playground.location
  address_space       = ["10.23.0.0/16"]
}

resource "azurerm_subnet" "kind-internal" {
  name                 = "kind-internal"
  resource_group_name  = azurerm_resource_group.kind-playground.name
  virtual_network_name = azurerm_virtual_network.kind-playground.name
  address_prefixes     = ["10.23.1.0/24"]
}

resource "azurerm_network_interface" "kind-nic" {
  name                = "kind-nic"
  location            = azurerm_resource_group.kind-playground.location
  resource_group_name = azurerm_resource_group.kind-playground.name

  ip_configuration {
    name                          = "public"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.kind.id
    primary                       = "true"
    subnet_id                     = azurerm_subnet.kind-internal.id
  }
}

resource "azurerm_public_ip" "kind" {
  name                = "kind"
  resource_group_name = azurerm_resource_group.kind-playground.name
  location            = azurerm_resource_group.kind-playground.location
  allocation_method   = "Static"
}
