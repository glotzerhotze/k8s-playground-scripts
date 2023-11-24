# Create a resource group for the KIND VM
resource "azurerm_resource_group" "kind-playground" {
  name     = "kind-playground"
  location = "West Europe"
}
