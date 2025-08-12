# Vault Integration with AI Pipeline Nomad Infrastructure

This directory now includes HashiCorp Vault deployment integrated with your existing Nomad cluster infrastructure.

## Overview

The Vault integration provides:
- **3-node HA Vault cluster** with Raft storage
- **Automatic unsealing** using the vault-unsealer service
- **JWT authentication** for Nomad workload identities
- **Secure secret management** for your AI pipeline applications

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Vault Node 1  │    │   Vault Node 2  │    │   Vault Node 3  │
│   (Port 8200)   │    │   (Port 8200)   │    │   (Port 8200)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Vault Unsealer  │
                    │ (Auto-unseals)  │
                    └─────────────────┘
```

## Files Added

- **`vault.tf`** - Terraform configuration for Vault deployment
- **`vault.nomad`** - Nomad job specification for Vault cluster
- **`vault-unsealer.nomad`** - Nomad job for automatic unsealing
- **`VAULT_README.md`** - This documentation file

## Configuration

### Variables

The following variables control Vault deployment:

```hcl
variable "vault_enabled" {
  description = "Whether to deploy Vault into the Nomad cluster"
  type        = bool
  default     = true
}
```

### Node Requirements

Vault nodes run on the existing Nomad server nodes with:
- **Node pool**: `vault-servers`
- **Resources**: 500m CPU, 1024MB RAM per node
- **Ports**: 8200 (API), 8201 (cluster)
- **Storage**: Host volume for Raft data

## Deployment

### 1. Deploy Infrastructure

```bash
cd ai-pipeline-nomad-vault/infrastructure
terraform init
terraform plan
terraform apply
```

### 2. Verify Vault Deployment

```bash
# Check Vault namespace
nomad namespace list

# Check Vault jobs
nomad job list -namespace=vault-cluster

# Check Vault service
nomad service list -namespace=vault-cluster
```

### 3. Access Vault UI

The Vault UI will be available at:
```
http://<server-ip>:8200
```

## Integration with Existing Jobs

Your existing Nomad jobs can now use Vault for secret management:

### Example: File Processor with Vault

```hcl
job "file-processor" {
  # ... existing configuration ...
  
  group "file-processor-group" {
    # ... existing configuration ...
    
    task "file-processor" {
      # ... existing configuration ...
      
      template {
        data = <<EOH
AZURE_STORAGE_ACCOUNT = "{{ with secret "azure/storage" }}{{ .Data.data.account_name }}{{ end }}"
AZURE_STORAGE_ACCESS_KEY = "{{ with secret "azure/storage" }}{{ .Data.data.access_key }}{{ end }}"
EOH
        destination = "local/env"
        env         = true
      }
    }
  }
}
```

## Security Features

- **Raft consensus** for high availability
- **Automatic unsealing** eliminates manual intervention
- **JWT authentication** for secure workload identity
- **Namespace isolation** in Nomad
- **Host networking** for performance

## Monitoring

### Health Checks

Vault includes built-in health checks:
- API endpoint health monitoring
- Service discovery via Nomad
- Automatic failover between nodes

### Logs

```bash
# View Vault logs
nomad alloc logs -f <allocation-id>

# View unsealer logs
nomad alloc logs -f -namespace=vault-cluster <unsealer-allocation-id>
```

## Troubleshooting

### Common Issues

1. **Vault not initializing**: Check unsealer logs and ensure keys are properly stored
2. **JWT auth not working**: Verify Nomad is generating proper JWTs
3. **Storage issues**: Ensure host volumes are properly configured

### Debug Commands

```bash
# Check Vault status
curl http://<server-ip>:8200/v1/sys/health

# Check JWT configuration
curl -H "X-Vault-Token: <root-token>" \
  http://<server-ip>:8200/v1/auth/jwt/config

# Check Nomad JWT endpoint
curl http://<server-ip>:4646/.well-known/jwks.json
```

## Next Steps

1. **Configure secrets** in Vault for your applications
2. **Set up policies** for different job types
3. **Integrate existing jobs** to use Vault secrets
4. **Monitor and maintain** the Vault cluster

## Support

For issues with the Vault integration:
1. Check the troubleshooting section above
2. Review Nomad and Vault logs
3. Verify network connectivity between nodes
4. Ensure proper resource allocation
