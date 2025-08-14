# NOTE: These must match the values set in /nomad/variables.hcl
locals {
  azure_resource_group_name = "ai_dev"
  azure_location            = "eastus"
}

data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Azure AD Application for Nomad auto-join
resource "azuread_application_registration" "nomad_autojoin" {
  display_name = "nomad-autojoin-authapp"
}

resource "azuread_application_password" "nomad_autojoin" {
  application_id = azuread_application_registration.nomad_autojoin.id
}

resource "azuread_service_principal" "nomad_autojoin" {
  client_id = azuread_application_registration.nomad_autojoin.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

# Grant the service principal permissions to access Azure resources
resource "azurerm_role_assignment" "nomad_autojoin" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.nomad_autojoin.object_id
}

resource "random_uuid" "nomad_id" {
}

resource "random_uuid" "nomad_token" {
}

resource "random_string" "vm_password" {
  length  = 16
  special = false
}

data "azurerm_resource_group" "ai_dev" {
  name = var.name_prefix
}

resource "azurerm_virtual_network" "ai_dev_vn" {
  name                = "${local.prefix}-vn"
  address_space       = ["10.0.0.0/16"]
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name
}

# Private clients

resource "azurerm_subnet" "private_clients_subnet" {
  name                 = "${local.prefix}-private-clients-subnet"
  resource_group_name  = data.azurerm_resource_group.ai_dev.name
  virtual_network_name = azurerm_virtual_network.ai_dev_vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "private_clients_security_group" {
  name                = "${local.prefix}-private-clients-sg"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name
}

resource "azurerm_subnet_network_security_group_association" "private_clients_sg_association" {
  subnet_id                 = azurerm_subnet.private_clients_subnet.id
  network_security_group_id = azurerm_network_security_group.private_clients_security_group.id
}

# Allow all internal communication between private clients
resource "azurerm_network_security_rule" "private_clients_internal_all" {
  name                        = "${local.prefix}-private-clients-internal-all"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.private_clients_security_group.name

  priority  = 110
  direction = "Inbound"
  access    = "Allow"
  protocol  = "*"

  source_address_prefix      = "VirtualNetwork"
  source_port_range          = "*"
  destination_port_range     = "*"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "private_clients_outbound" {
  name                        = "${local.prefix}-private-clients-outbound"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.private_clients_security_group.name

  priority  = 111
  direction = "Outbound"
  access    = "Allow"
  protocol  = "*"

  source_address_prefix      = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "private_clients_ssh_ingress" {
  name                        = "${local.prefix}-private-clients-ssh-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.private_clients_security_group.name

  priority  = 112
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = var.azure_allowlist_ip
  source_port_range          = "*"
  destination_port_range     = "22"
  destination_address_prefix = "*"
}

# Allow Vault API access on port 8200
resource "azurerm_network_security_rule" "private_clients_vault_api_ingress" {
  name                        = "${local.prefix}-private-clients-vault-api-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.private_clients_security_group.name

  priority  = 113
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = var.azure_allowlist_ip
  source_port_range          = "*"
  destination_port_range     = "8200"
  destination_address_prefix = "*"
}

resource "azurerm_public_ip" "private_client_public_ip" {
  count               = var.azure_private_client_count
  name                = "${local.prefix}-private-client-ip-${count.index}"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Vault client public IP addresses
resource "azurerm_public_ip" "vault_client_public_ip" {
  count               = var.azure_vault_client_count
  name                = "${local.prefix}-vault-client-ip-${count.index}"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "private_client_ni" {
  count               = var.azure_private_client_count
  name                = "${local.prefix}-private-client-ni-${count.index}"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name

  ip_configuration {
    name                          = "${local.prefix}-private-client-ipc"
    subnet_id                     = azurerm_subnet.private_clients_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.private_client_public_ip.*.id, count.index)
  }

  tags = {
    "NomadJoinTag" = "auto-join"
  }
}

# Vault client network interfaces
resource "azurerm_network_interface" "vault_client_ni" {
  count               = var.azure_vault_client_count
  name                = "${local.prefix}-vault-client-ni-${count.index}"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name

  ip_configuration {
    name                          = "${local.prefix}-vault-client-ipc"
    subnet_id                     = azurerm_subnet.private_clients_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.vault_client_public_ip.*.id, count.index)
  }

  tags = {
    "NomadJoinTag" = "auto-join"
  }
}

# Public clients

resource "azurerm_subnet" "public_clients_subnet" {
  name                 = "${local.prefix}-public-clients-subnet"
  resource_group_name  = data.azurerm_resource_group.ai_dev.name
  virtual_network_name = azurerm_virtual_network.ai_dev_vn.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_network_security_group" "public_clients_security_group" {
  name                = "${local.prefix}-public-clients-sg"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name
}

resource "azurerm_subnet_network_security_group_association" "public_clients_sg_association" {
  subnet_id                 = azurerm_subnet.public_clients_subnet.id
  network_security_group_id = azurerm_network_security_group.public_clients_security_group.id
}

# Allow all internal communication between public clients
resource "azurerm_network_security_rule" "public_clients_internal_all" {
  name                        = "${local.prefix}-public-clients-internal-all"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.public_clients_security_group.name

  priority  = 210
  direction = "Inbound"
  access    = "Allow"
  protocol  = "*"

  source_address_prefix      = "VirtualNetwork"
  source_port_range          = "*"
  destination_port_range     = "*"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "public_clients_outbound" {
  name                        = "${local.prefix}-public-clients-outbound"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.public_clients_security_group.name

  priority  = 211
  direction = "Outbound"
  access    = "Allow"
  protocol  = "*"

  source_address_prefix      = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "public_clients_ssh_ingress" {
  name                        = "${local.prefix}-public-clients-ssh-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.public_clients_security_group.name

  priority  = 212
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = var.azure_allowlist_ip
  source_port_range          = "*"
  destination_port_range     = "22"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "public_clients_external_ingress" {
  name                        = "${local.prefix}-public-clients-external-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.public_clients_security_group.name

  priority  = 213
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = "*"
  source_port_range          = "*"
  destination_port_ranges    = ["80", "3000", "8081"]
  destination_address_prefix = "*"
}

resource "azurerm_public_ip" "public_client_public_ip" {
  count               = var.azure_public_client_count
  name                = "${local.prefix}-public-client-ip-${count.index}"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "public_client_ni" {
  count               = var.azure_public_client_count
  name                = "${local.prefix}-public-client-ni-${count.index}"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name

  ip_configuration {
    name                          = "${local.prefix}-public-client-ipc"
    subnet_id                     = azurerm_subnet.public_clients_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.public_client_public_ip.*.id, count.index)
  }

  tags = {
    "NomadJoinTag" = "auto-join"
  }
}

# Server nodes
resource "azurerm_subnet" "servers_subnet" {
  name                 = "${local.prefix}-servers-subnet"
  resource_group_name  = data.azurerm_resource_group.ai_dev.name
  virtual_network_name = azurerm_virtual_network.ai_dev_vn.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "servers_security_group" {
  name                = "${local.prefix}-servers-sg"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name
}

resource "azurerm_subnet_network_security_group_association" "servers_sg_association" {
  subnet_id                 = azurerm_subnet.servers_subnet.id
  network_security_group_id = azurerm_network_security_group.servers_security_group.id
}

# Critical Nomad cluster communication ports
resource "azurerm_network_security_rule" "servers_nomad_rpc_ingress" {
  name                        = "${local.prefix}-servers-nomad-rpc-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.servers_security_group.name

  priority  = 310
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = "VirtualNetwork"
  source_port_range          = "*"
  destination_port_range     = "4647"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "servers_serf_wan_ingress" {
  name                        = "${local.prefix}-servers-serf-wan-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.servers_security_group.name

  priority  = 311
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = "VirtualNetwork"
  source_port_range          = "*"
  destination_port_range     = "8302"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "servers_serf_lan_ingress" {
  name                        = "${local.prefix}-servers-serf-lan-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.servers_security_group.name

  priority  = 312
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = "VirtualNetwork"
  source_port_range          = "*"
  destination_port_range     = "8301"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "servers_outbound" {
  name                        = "${local.prefix}-servers-outbound"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.servers_security_group.name

  priority  = 313
  direction = "Outbound"
  access    = "Allow"
  protocol  = "*"

  source_address_prefix      = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "servers_ssh_ingress" {
  name                        = "${local.prefix}-servers-ssh-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.servers_security_group.name

  priority  = 314
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = var.azure_allowlist_ip
  source_port_range          = "*"
  destination_port_range     = "22"
  destination_address_prefix = "*"
}

resource "azurerm_network_security_rule" "servers_nomad_ui_ingress" {
  name                        = "${local.prefix}-servers-nomad-ui-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.servers_security_group.name

  priority  = 315
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = var.azure_allowlist_ip
  source_port_range          = "*"
  destination_port_range     = "4646"
  destination_address_prefix = "*"
}

# Allow all internal communication between servers
resource "azurerm_network_security_rule" "servers_internal_all" {
  name                        = "${local.prefix}-servers-internal-all"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.servers_security_group.name

  priority  = 316
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = "VirtualNetwork"
  source_port_range          = "*"
  destination_port_range     = "*"
  destination_address_prefix = "VirtualNetwork"
}

resource "azurerm_public_ip" "server_public_ip" {
  count               = var.azure_server_count
  name                = "${local.prefix}-server-ip-${count.index}"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "server_ni" {
  count               = var.azure_server_count
  name                = "${local.prefix}-server-ni-${count.index}"
  location            = var.azure_location
  resource_group_name = data.azurerm_resource_group.ai_dev.name

  ip_configuration {
    name                          = "${local.prefix}-server-ipc"
    subnet_id                     = azurerm_subnet.servers_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.server_public_ip.*.id, count.index)
  }

  tags = {
    "NomadJoinTag" = "auto-join"
  }
}

# Associate security group with server network interfaces
resource "azurerm_network_interface_security_group_association" "server_sg_association" {
  count                     = var.azure_server_count
  network_interface_id      = azurerm_network_interface.server_ni[count.index].id
  network_security_group_id = azurerm_network_security_group.servers_security_group.id
}

# Workshop Application Network Security Rules

# OpenWebUI ingress rule for public clients
resource "azurerm_network_security_rule" "public_clients_openwebui_ingress" {
  name                        = "${local.prefix}-public-clients-openwebui-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.public_clients_security_group.name

  priority  = 220
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = var.azure_allowlist_ip
  source_port_range          = "*"
  destination_port_range     = "8080"
  destination_address_prefix = "*"
}

# OpenWebUI HTTPS ingress rule for public clients
resource "azurerm_network_security_rule" "public_clients_openwebui_https_ingress" {
  name                        = "${local.prefix}-public-clients-openwebui-https-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.public_clients_security_group.name

  priority  = 221
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = var.azure_allowlist_ip
  source_port_range          = "*"
  destination_port_range     = "443"
  destination_address_prefix = "*"
}

# Web Upload App ingress rule for public clients
resource "azurerm_network_security_rule" "public_clients_web_upload_ingress" {
  name                        = "${local.prefix}-public-clients-web-upload-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.public_clients_security_group.name

  priority  = 222
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = var.azure_allowlist_ip
  source_port_range          = "*"
  destination_port_range     = "3000"
  destination_address_prefix = "*"
}

# File Processor ingress rule for private clients
resource "azurerm_network_security_rule" "private_clients_file_processor_ingress" {
  name                        = "${local.prefix}-private-clients-file-processor-ingress"
  resource_group_name         = data.azurerm_resource_group.ai_dev.name
  network_security_group_name = azurerm_network_security_group.private_clients_security_group.name

  priority  = 120
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_address_prefix      = "VirtualNetwork"
  source_port_range          = "*"
  destination_port_range     = "8081"
  destination_address_prefix = "*"
}