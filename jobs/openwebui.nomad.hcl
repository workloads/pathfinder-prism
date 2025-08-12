# Variable declarations for OpenWebUI
variable "azure_storage_account" {
  type = string
}

variable "azure_storage_access_key" {
  type = string
}

variable "azure_storage_connection_string" {
  type = string
}

variable "client_ip" {
  type = string
}

variable "azure_region" {
  type = string
}

variable "openwebui_oidc_tenant_id" {
  type = string
}

variable "openwebui_oidc_client_id" {
  type = string
}

variable "openwebui_oidc_client_secret" {
  type = string
}

variable "openwebui_api_key" {
  type = string
}

job "openwebui" {
  type = "service"

  group "openwebui-group" {
    count = 1

    # Constraint to run on public clients only
    constraint {
      attribute = "${meta.isPublic}"
      operator  = "="
      value     = "true"
    }

    network {
      port "http" {
        static = 8080
      }
      # port "https" {
      #   to = 443
      #   static = 443
      # }
    }

    task "openwebui" {
      driver = "docker"

      service {
        name = "openwebui"
        port = "http"
        provider = "nomad"

        check {
          type     = "http"
          name     = "openwebui-health"
          path     = "/api/v1/health"
          interval = "30s"
          timeout  = "5s"
        }
      }

      config {
        image = "ghcr.io/open-webui/open-webui:main"
        ports = ["http"]
      }

      resources {
        cpu    = 1000
        memory = 2000
      }

      env {
        # OpenWebUI Configuration
        WEBUI_SECRET_KEY = var.openwebui_api_key
        WEBUI_AUTH = "True"
        WEBUI_URL = "http://${var.client_ip}:8080"
        # ENABLE_OAUTH_SIGNUP = "True"
        ENABLE_LOGIN_FORM = "True"
        ENABLE_SIGNUP="True"

        # OIDC Configuration
        # WEBUI_AUTH_OIDC_ENABLED = "True"
        # OAUTH_PROVIDER_NAME = "azure"
        # OAUTH_CLIENT_ID = var.openwebui_oidc_client_id
        # OAUTH_CLIENT_SECRET = var.openwebui_oidc_client_secret
        # OPENID_PROVIDER_URL = "https://login.microsoftonline.com/${var.openwebui_oidc_tenant_id}/v2.0"
        # OAUTH_SCOPES = "openid profile email"
        # OPENID_REDIRECT_URI = "https://${var.client_ip}/auth/callback"

        # Ollama Configuration
        ENABLE_OLLAMA_API = "True"
        ENABLE_OPENAI_API = "False"

        # Azure Blob Storage for Knowledge Base
        STORAGE_PROVIDER = "azure"
        AZURE_STORAGE_ENDPOINT = "https://${var.azure_storage_account}.blob.core.windows.net"
        AZURE_STORAGE_KEY = var.azure_storage_access_key
        AZURE_STORAGE_CONTAINER_NAME = "knowledge-base"

        # RAG Content Extraction Engine Configuration
        # CONTENT_EXTRACTION_ENGINE = "docling"
        # DOCLING_SERVER_URL = "http://{{ range nomadService \"docling\" }}{{ .Address }}:{{ .Port }}{{ end }}"
        # WEBUI_RAG_CONTENT_EXTRACTION_ENGINE_DESCRIBE_PICTURES = "True"
        # WEBUI_RAG_CONTENT_EXTRACTION_ENGINE_PICTURE_DESCRIPTION_MODE = "local"
      }

      template {
        data = <<EOH
OLLAMA_BASE_URL="{{ range nomadService "ollama-backend" }}http://{{ .Address }}:{{ .Port }}{{ end }}"
EOH
        destination = "local/env.txt"
        env         = true
        change_mode = "restart"
      }
    }

#     task "caddy" {
#       driver = "docker"

#       service {
#         name = "caddy"
#         port = "https"
#         provider = "nomad"

#         check {
#           type     = "http"
#           name     = "caddy-health"
#           path     = "/"
#           interval = "30s"
#           timeout  = "5s"
#         }
#       }

#       config {
#         image = "caddy:2-alpine"
#         ports = ["https"]
#         volumes = [
#           "local/Caddyfile:/etc/caddy/Caddyfile",
#           "local/caddy_data:/data",
#           "local/caddy_config:/config"
#         ]
#       }

#       resources {
#         cpu    = 500
#         memory = 512
#       }

#       template {
#         data = <<EOH
# ${var.client_ip} {
#   reverse_proxy localhost:8080
# }
# EOH
#         destination = "local/Caddyfile"
#         change_mode = "restart"
#       }
#     }
  }
} 