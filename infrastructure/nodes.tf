locals {
  # Azure cloud auto-join using tags with required authentication
  retry_join = "provider=azure tag_name=NomadJoinTag tag_value=auto-join subscription_id=${data.azurerm_client_config.current.subscription_id} tenant_id=${data.azurerm_client_config.current.tenant_id} client_id=${azuread_application_registration.nomad_autojoin.client_id} secret_access_key=${azuread_application_password.nomad_autojoin.value}"
}

#-------------------------------------------------------------------------------
# Nomad Server(s)
#-------------------------------------------------------------------------------

resource "azurerm_linux_virtual_machine" "server" {
  count                           = var.azure_server_count
  name                            = "${local.prefix}-server-${count.index}"
  location                        = var.azure_location
  resource_group_name             = data.azurerm_resource_group.ai_dev.name
  size                            = var.azure_server_instance_type
  admin_username                  = "ubuntu"
  admin_password                  = random_string.vm_password.result
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.server_ni[count.index].id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "${local.prefix}-server-osdisk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name = replace("${local.prefix}-server-${count.index}", "_", "-")

  custom_data = base64encode(templatefile("${path.module}/shared/data-scripts/user-data-server.sh", {
    domain                 = var.domain
    datacenter             = var.datacenter
    server_count           = var.azure_server_count
    cloud_env              = "azure"
    retry_join             = local.retry_join
    nomad_node_name        = "azure-server-${count.index}"
    nomad_encryption_key   = random_id.nomad_gossip_key.b64_std
    nomad_management_token = random_uuid.nomad_mgmt_token.result
    tls_enabled            = false
    ca_certificate         = ""
    agent_certificate      = ""
    agent_key              = ""
  }))

  tags = {
    Name         = "${local.prefix}-server-${count.index}"
    NomadType    = "server"
    NomadJoinTag = "auto-join"
  }

  # Wait for cloud-init to complete and Nomad to be ready
  provisioner "remote-exec" {
    connection {
      host     = self.public_ip_address
      user     = self.admin_username
      password = self.admin_password
    }

    inline = [
      "echo 'Waiting for user data script to finish...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Waiting for Nomad service to be ready...'",
      "until systemctl is-active --quiet nomad; do sleep 5; done",
      "echo 'Nomad service is ready!'"
    ]
  }
}

# Private client nodes

resource "azurerm_linux_virtual_machine" "private_client" {
  name                  = "${local.prefix}-private-client-${count.index}"
  location              = var.azure_location
  resource_group_name   = data.azurerm_resource_group.ai_dev.name
  network_interface_ids = ["${element(azurerm_network_interface.private_client_ni.*.id, count.index)}"]
  size                  = var.azure_private_client_instance_type
  count                 = var.azure_private_client_count
  depends_on            = [azurerm_linux_virtual_machine.server]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "${local.prefix}-private-client-osdisk-${count.index}-0"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name  = replace("${local.prefix}-private-client-${count.index}-0", "_", "-")
  admin_username = "ubuntu"
  admin_password = random_string.vm_password.result
  custom_data = (base64encode(templatefile("${path.module}/shared/data-scripts/user-data-client.sh", {
    domain            = var.domain
    datacenter        = var.datacenter
    nomad_node_name   = "azure-private-client-${count.index}-0"
    nomad_agent_meta  = "isPublic=false,cloud=azure"
    region            = var.azure_location
    cloud_env         = "azure"
    node_pool         = "default"
    retry_join        = local.retry_join
    tls_enabled       = false
    ca_certificate    = ""
    agent_certificate = ""
    agent_key         = ""
  })))

  disable_password_authentication = false

  tags = {
    Name         = "${local.prefix}-private-client-${count.index}"
    NomadJoinTag = "auto-join"
    NomadType    = "client"
  }
}

resource "azurerm_linux_virtual_machine" "private_client_vault" {
  name                  = "${local.prefix}-private-client-vault-${count.index}"
  location              = var.azure_location
  resource_group_name   = data.azurerm_resource_group.ai_dev.name
  network_interface_ids = ["${element(azurerm_network_interface.vault_client_ni.*.id, count.index)}"]
  size                  = var.azure_vault_instance_type
  count                 = var.azure_vault_client_count
  depends_on            = [azurerm_linux_virtual_machine.server]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "${local.prefix}-private-client-osdisk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name  = replace("${local.prefix}-private-client-${count.index}", "_", "-")
  admin_username = "ubuntu"
  admin_password = random_string.vm_password.result
  custom_data = (base64encode(templatefile("${path.module}/shared/data-scripts/user-data-client.sh", {
    domain            = var.domain
    datacenter        = var.datacenter
    nomad_node_name   = "azure-private-client-${count.index}"
    nomad_agent_meta  = "isPublic=false,cloud=azure,isVault=true"
    region            = var.azure_location
    cloud_env         = "azure"
    node_pool         = "vault-servers"
    retry_join        = local.retry_join
    tls_enabled       = false
    ca_certificate    = ""
    agent_certificate = ""
    agent_key         = ""
  })))

  disable_password_authentication = false

  tags = {
    Name         = "${local.prefix}-private-client-${count.index}"
    NomadJoinTag = "auto-join"
    NomadType    = "client"
  }
}

# Public client nodes

resource "azurerm_linux_virtual_machine" "public_client" {
  name                  = "${local.prefix}-public-client-${count.index}"
  location              = var.azure_location
  resource_group_name   = data.azurerm_resource_group.ai_dev.name
  network_interface_ids = ["${element(azurerm_network_interface.public_client_ni.*.id, count.index)}"]
  size                  = var.azure_public_client_instance_type
  count                 = var.azure_public_client_count
  depends_on            = [azurerm_linux_virtual_machine.server]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name                 = "${local.prefix}-public-client-osdisk-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name  = replace("${local.prefix}-public-client-${count.index}", "_", "-")
  admin_username = "ubuntu"
  admin_password = random_string.vm_password.result
  custom_data = (base64encode(templatefile("${path.module}/shared/data-scripts/user-data-client.sh", {
    domain            = var.domain
    datacenter        = var.datacenter
    nomad_node_name   = "azure-public-client-${count.index}"
    nomad_agent_meta  = "isPublic=true,cloud=azure"
    region            = var.azure_location
    cloud_env         = "azure"
    node_pool         = "default"
    retry_join        = local.retry_join
    tls_enabled       = false
    ca_certificate    = ""
    agent_certificate = ""
    agent_key         = ""
  })))

  disable_password_authentication = false

  tags = {
    Name         = "${local.prefix}-public-client-${count.index}"
    NomadJoinTag = "auto-join"
    NomadType    = "client"
  }
}