# Variable declarations for web upload app
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

variable "openwebui_api_key" {
  type = string
}

job "web-upload-app" {
  type = "service"

  group "web-upload-group" {
    count = 1

    # Constraint to run on public clients only
    constraint {
      attribute = "${meta.isPublic}"
      operator  = "="
      value     = "true"
    }

    network {
      port "http" {
        to = 3000
        static = 3000
      }
    }

    task "web-upload-app" {
      driver = "docker"

      service {
        name = "web-upload-app"
        port = "http"
        provider = "nomad"

        check {
          type     = "http"
          name     = "web-upload-app-health"
          path     = "/api/health"
          interval = "30s"
          timeout  = "5s"
        }
      }

      config {
        image = "im2nguyenhashi/web-upload-app:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 1000
      }

      env {
        AZURE_STORAGE_ACCOUNT = var.azure_storage_account
        AZURE_STORAGE_ACCESS_KEY = var.azure_storage_access_key
        AZURE_STORAGE_CONNECTION_STRING = var.azure_storage_connection_string
        UPLOAD_CONTAINER = "uploads"
        NEXT_PUBLIC_APP_URL = "http://${var.client_ip}:3000"

      }
    }
  }
} 