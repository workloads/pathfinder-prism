# Variable declarations for file processor
variable "azure_storage_account" {
  type = string
}

variable "azure_storage_access_key" {
  type = string
}

variable "azure_storage_connection_string" {
  type = string
}

variable "openwebui_api_key" {
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

variable "vault_addr" {
  type = string
}

variable "vault_token" {
  type = string
}

variable "vault_transform_path" {
  type = string
}

variable "vault_role" {
  type = string
}

job "file-processor" {
  type = "service"

  group "file-processor-group" {
    count = 1

    # Constraint to run on private clients only
    constraint {
      attribute = "${meta.isPublic}"
      operator  = "="
      value     = "true"
    }

    network {
      port "http" {
        to = 8081
        static = 8081
      }
    }

    task "file-processor" {
      driver = "docker"

      service {
        name = "file-processor"
        port = "http"
        provider = "nomad"

        check {
          type     = "http"
          name     = "file-processor-health"
          path     = "/health"
          interval = "30s"
          timeout  = "5s"
        }
      }

      config {
        image = "im2nguyenhashi/file-processor:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      env {
        AZURE_STORAGE_ACCOUNT = var.azure_storage_account
        AZURE_STORAGE_ACCESS_KEY = var.azure_storage_access_key
        AZURE_STORAGE_CONNECTION_STRING = var.azure_storage_connection_string
        OPENWEBUI_API_KEY = var.openwebui_api_key
        PROCESSING_INTERVAL = "30"
        UPLOAD_CONTAINER = "uploads"
        PROCESSED_CONTAINER = "processed"
        KNOWLEDGE_BASE_CONTAINER = "knowledge-base"
        OPENWEBUI_URL = "http://${var.client_ip}:8080"
        VAULT_ADDR = var.vault_addr
        VAULT_TOKEN = var.vault_token
        VAULT_TRANSFORM_PATH = var.vault_transform_path
        VAULT_ROLE = var.vault_role
      }

      template {
        data = <<EOH
OPENWEBUI_URL="{{ range nomadService "openwebui" }}http://{{ .Address }}:{{ .Port }}{{ end }}"
EOH
        destination = "local/openwebui_url.txt"
        env         = true
        change_mode = "restart"
      }
    }
  }
} 