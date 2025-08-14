job "ollama" {
  type = "service"
  
  group "ollama" {  
    constraint {
        attribute = "${meta.isPublic}"
        operator  = "="
        value     = "false"
    }
    
    count = 1
    network {
      port "ollama" {
        to = 11434
        static = 8081
      }
    }

    task "ollama-task" {
      driver = "docker"

      service {
        name = "ollama-backend"
        port = "ollama"
        provider = "nomad"
      }
      
      config {
        image = "ollama/ollama"
        ports = ["ollama"]
      }

      resources {
        cpu    = 2500
        memory = 7000
      }
    }

    task "download-granite-vision-model" {
        driver = "exec"
        lifecycle {
            hook = "poststart"
        }
        resources {
            cpu    = 100
            memory = 100
        }
        template {
            data        = <<EOH
{{ range nomadService "ollama-backend" }}
OLLAMA_BASE_URL="http://{{ .Address }}:{{ .Port }}"
{{ end }}
EOH
            destination = "local/env.txt"
            env         = true
      }
        config {
            command = "/bin/bash"
            args = [
                "-c",
                "curl -X POST ${OLLAMA_BASE_URL}/api/pull -d '{\"name\": \"granite3.2-vision\"}'"
            ]
        }
    }

    task "download-granite-code-model" {
        driver = "exec"
        lifecycle {
            hook = "poststart"
        }
        resources {
            cpu    = 100
            memory = 100
        }
        template {
            data        = <<EOH
{{ range nomadService "ollama-backend" }}
OLLAMA_BASE_URL="http://{{ .Address }}:{{ .Port }}"
{{ end }}
EOH
            destination = "local/env.txt"
            env         = true
      }
        config {
            command = "/bin/bash"
            args = [
                "-c",
                "curl -X POST ${OLLAMA_BASE_URL}/api/pull -d '{\"name\": \"granite-code\"}'"
            ]
        }
    }
  }
}