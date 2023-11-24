resource "azurerm_linux_virtual_machine" "kind" {
  name                  = "kind"
  location              = azurerm_resource_group.kind-playground.location
  resource_group_name   = azurerm_resource_group.kind-playground.name
  network_interface_ids = [azurerm_network_interface.kind-nic.id]
  size                  = "Standard_F2"
  admin_username        = "k8s"
  user_data             = filebase64("./user-data/kind.sh")
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }
  admin_ssh_key {
    public_key = file("~/.ssh/id_rsa.pub")
    username   = "k8s"
  }
  tags = {
    environment = "kind-playground"
  }
}
