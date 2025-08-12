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
        WEBUI_AUTH = "True"
        WEBUI_URL = "http://${var.client_ip}:8080"
        ENABLE_LOGIN_FORM = "True"
        ENABLE_SIGNUP="True"

        # Ollama Configuration
        ENABLE_OLLAMA_API = "True"
        ENABLE_OPENAI_API = "False"

        # Azure Blob Storage for Knowledge Base
        STORAGE_PROVIDER = "azure"
        AZURE_STORAGE_ENDPOINT = "https://${var.azure_storage_account}.blob.core.windows.net"
        AZURE_STORAGE_KEY = var.azure_storage_access_key
        AZURE_STORAGE_CONTAINER_NAME = "knowledge-base"
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