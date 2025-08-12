    job "docling" {
      type        = "service"

      group "docling" {
        count = 1

        # Constraint to run on public clients only (same as other services)
        constraint {
          attribute = "${meta.isPublic}"
          operator  = "="
          value     = "true"
        }

        network {
          port "http" {
            to = 5001
            static = 5001
          }
        }

        task "docling" {
          driver = "docker"

          config {
            image = "ghcr.io/docling-project/docling-serve:latest"
            ports = ["http"]
          }

          env {
            DOCLING_SERVE_ENABLE_UI = "true"
          }

          resources {
            cpu    = 4000
            memory = 8192
          }

          service {
            name = "docling"
            port = "http"
            provider = "nomad"

            # check {
            #   type     = "http"
            #   path     = "/health"
            #   interval = "30s"
            #   timeout  = "10s"
            #   initial_status = "passing"
            # }
          }

          logs {
            max_files     = 3
            max_file_size = 10
          }
        }
      }
    } 