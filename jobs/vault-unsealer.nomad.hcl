job "vault-unsealer" {
  namespace   = "vault-cluster"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "vault-servers"

  group "vault-unsealer" {
    count = 1

    constraint {
      attribute = "${meta.isVault}"
      operator  = "="
      value     = "true"
    }

    task "vault-unsealer" {
      driver = "docker"

      config {
        image = "devopsrob/vault-unsealer:0.2"

        command = "./vault-unsealer"
        volumes = [
          "local/config:/app/config"
        ]
      }

      template {
        data = <<EOH
{
  "log_level": "debug",
  "probe_interval": 10,
  "nodes": [
{{- $nodes := nomadService "vault" }}
{{- range $i, $e := $nodes }}
    {{- if $i }},{{ end }}
    "http://{{ .Address }}:{{ .Port }}"
{{- end }}
  ],
  "unseal_keys": [
    {{- with nomadVar "nomad/jobs/vault-unsealer" }}
    "{{ .key1 }}"
    {{- end }}
  ]
}
EOH

        destination = "local/config/config.json"
        change_mode = "noop"
      }

      resources {
        cpu    = 100
        memory = 512
      }

      affinity {
        attribute = "${meta.node_id}"
        value     = "${NOMAD_ALLOC_ID}"
        weight    = 100
      }
    }
  }
}
