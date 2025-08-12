# File processor with vault PII protection

This file processor application integrates with HashiCorp Vault to provide enterprise-grade PII (Personally Identifiable Information) protection during document processing. This guide explains how the system works and how to use it effectively.

## Features and architecture

The processor converts various document formats to Markdown using DocLings, automatically detects and protects sensitive data using Vault, stores only protected versions for security, gracefully degrades when Vault is unavailable, and includes built-in comparison tools for demo demonstrations. It provides a document processing pipeline with comprehensive privacy protection.

The processor operates by taking documents from the upload container, converting them to markdown using DocLings, applying PII protection through Vault, and then storing only the protected version in the processed container. The protected version gets uploaded to OpenWebUI for knowledge base integration, while the original sensitive data is never stored.

```
Upload Container → File Processor → Docling → Vault Transform → Storage
                                    ↓
                              Markdown + PII Protection
                                    ↓
                    Protected version only (processed container)
```

## PII protection methods

The processor uses two approaches to secure sensitive information. Tokenization replaces highly sensitive data like Social Security Numbers and email addresses with secure tokens (like `tok_abc123def`) that can be reversed with proper Vault authorization. This approach provides maximum security for data that absolutely cannot be exposed.

Masking hides patterns in less sensitive data like phone numbers and bank account numbers by replacing parts with asterisks (like `***-***-4567`). This method is simpler and faster than tokenization but not reversible - it's ideal for data where you just need to hide the pattern.

## Configuration and usage

The application requires several environment variables to function properly. You'll need Azure storage credentials for blob access, OpenWebUI configuration for the knowledge base, Vault connection details for PII protection, and container names for organizing your files.

```bash
# Required
AZURE_STORAGE_ACCOUNT=your_storage_account
AZURE_STORAGE_ACCESS_KEY=your_access_key
OPENWEBUI_URL=http://openwebui:8080
OPENWEBUI_API_KEY=your_api_key

# Vault Configuration
VAULT_ADDR=http://vault-ip:8200
VAULT_TOKEN=your_vault_token
VAULT_TRANSFORM_PATH=ai_data_transform
VAULT_ROLE=file-processor

# Storage Containers
UPLOAD_CONTAINER=uploads
PROCESSED_CONTAINER=processed
KNOWLEDGE_BASE_CONTAINER=knowledge-base
```

You can run the processor in several ways. Start both the health server and processor together, or use Docker for containerized deployment. The health server provides monitoring endpoints while the processor handles the actual document processing.

```bash
# Start both health server and processor
python health_server.py & python process_documents.py

# Or use Docker
docker build -t file-processor .
docker run -e VAULT_TOKEN=your_token file-processor
```

Place documents in the `uploads` container and the processor will automatically handle them. It converts documents to Markdown using DocLings, applies PII protection through Vault, stores the protected version securely in the `processed` container, and uploads it to the OpenWebUI knowledge base for AI interaction.

Check the health of your processor and compare document versions through the built-in endpoints. The health check tells you if everything is running, while the comparison endpoint shows you the before and after of PII protection.

```bash
# Health Check
curl http://localhost:8081/health

# Document Comparison
curl http://localhost:8081/demo/compare/document_name
```

## API endpoints and integration

The health server runs on port 8081 and provides two main endpoints. The health check endpoint tells you if the service is running, while the comparison endpoint lets you see how documents look before and after PII protection.

- `GET /health` - Health check
- `GET /demo/compare/{filename}` - Compare original vs protected document

The comparison endpoint returns a JSON response showing the protected content and metadata about the PII protection that was applied. This includes counts of different types of PII detected and the protection method used.

```json
{
  "protected": "Protected markdown content without PII",
  "metadata": {
    "pii_protection": {
      "vault_used": true,
      "protection_method": "vault_kv",
      "total_pii_items": 6,
      "ssn_count": 1,
      "email_count": 3,
      "phone_count": 1,
      "bank_count": 1
    }
  },
  "comparison_available": true
}
```

## Vault integration and fallback

The application currently uses Vault KV for PII protection, which works with the Open Source version of Vault. It stores PII detection patterns and replacement strategies securely in Vault KV, then applies them using custom Python logic. This approach provides the security benefits of Vault without requiring an Enterprise license.

For Enterprise Vault users, the code includes commented-out Transform Engine integration. This would use Vault's built-in transformation capabilities for more secure and performant PII protection. To switch to this approach, uncomment the Transform Engine client initialization and update the protection logic.

When Vault is unavailable, the application gracefully falls back to basic regex-based protection. It still tokenizes SSNs and emails, and masks phone and bank numbers, but without the security benefits of Vault. This ensures your pipeline continues operating even if Vault is down.

## Demo content and troubleshooting

The application includes sample content for demonstrations, though only protected versions are stored in the system for security. You can see examples of PII protection in action and understand how different types of sensitive data are handled.

Vault connection failures usually stem from incorrect `VAULT_ADDR` or `VAULT_TOKEN` values. Verify Vault is running and accessible, and check your network connectivity. If PII isn't being detected, verify the regex patterns in your Vault KV configuration, check document format and encoding, and review the PII detection logic.

The application logs all operations to stdout/stderr with detailed information about document processing steps, PII detection and protection, Vault API calls and responses, and error conditions and fallbacks. When issues occur, check the logs first.

## Development and security

To add new types of PII detection, update the Vault KV patterns with new regex patterns, add detection logic in the `protect_pii_with_vault()` function, update the PII counting in metadata, and test with sample documents to ensure accuracy.

Modify the `VaultKVPIIProtector` methods to change how PII is detected and protected, update the fallback protection functions for offline scenarios, adjust chunking and processing logic for performance, and test error handling and edge cases thoroughly.

Vault tokens should be rotated regularly for security, and network access to Vault should be restricted to only necessary services. PII detection patterns should be reviewed for accuracy to avoid false positives or missed detections. The fallback protection provides basic security but isn't production-grade, so ensure Vault is always available in production. All sensitive data should be encrypted in transit and at rest.
