# Azure AD OIDC Configuration for OpenWebUI

# Azure AD Application Registration for OpenWebUI OIDC
# resource "azuread_application" "openwebui_oidc" {
#   display_name = "${local.prefix}-openwebui-oidc-app"

#   web {
#     redirect_uris = concat([
#       for ip in azurerm_linux_virtual_machine.public_client[*].public_ip_address :
#       "https://${ip}/auth/callback"
#     ], [
#       for ip in azurerm_linux_virtual_machine.public_client[*].public_ip_address :
#       "https://${ip}/auth/oidc/callback"
#     ])
    
#     implicit_grant {
#       access_token_issuance_enabled = true
#       id_token_issuance_enabled     = true
#     }
#   }

#   api {
#     oauth2_permission_scope {
#       admin_consent_description  = "Allow OpenWebUI to access user profile"
#       admin_consent_display_name = "Access user profile"
#       id                         = "00000000-0000-0000-0000-000000000001"
#       type                       = "User"
#       user_consent_description   = "Allow OpenWebUI to access your profile information"
#       user_consent_display_name  = "Access profile information"
#       value                      = "user_impersonation"
#     }
#   }

#   required_resource_access {
#     resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

#     resource_access {
#       id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
#       type = "Scope"
#     }
#   }
# }

# Client secret for the OIDC application
# resource "azuread_service_principal_password" "openwebui_oidc" {
#   service_principal_id = azuread_service_principal.openwebui_oidc.id
#   end_date_relative    = "8760h" # 1 year
# }

# Service principal for the OIDC application
# resource "azuread_service_principal" "openwebui_oidc" {
#   client_id = azuread_application.openwebui_oidc.client_id
#   owners    = [data.azuread_client_config.current.object_id]
# }

# Azure AD Application Registration for Web Upload App OIDC
resource "azuread_application_registration" "web_upload_oidc" {
  display_name = "${local.prefix}-web-upload-oidc-app"

  # OIDC configuration
  sign_in_audience = "AzureADMyOrg"
}

# Client secret for the Web Upload OIDC application
resource "azuread_application_password" "web_upload_oidc" {
  application_id = azuread_application_registration.web_upload_oidc.id
  display_name   = "Web Upload OIDC Client Secret"
}

# Service principal for the Web Upload OIDC application
resource "azuread_service_principal" "web_upload_oidc" {
  client_id = azuread_application_registration.web_upload_oidc.client_id
  owners    = [data.azuread_client_config.current.object_id]
} 