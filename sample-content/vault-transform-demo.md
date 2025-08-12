# Vault Transform Engine Demo Guide

## Overview
This demo shows how HashiCorp Vault's Transform Engine automatically detects and tokenizes Personally Identifiable Information (PII) in documents before they're stored in the knowledge base.

## What You'll See

### 1. Document Upload
- Upload `pii-demo-before.md` to the web interface
- This document contains various types of PII:
  - Social Security Numbers (SSN)
  - Email addresses
  - Phone numbers
  - Bank account numbers

### 2. Processing Pipeline
1. **DocLing** converts the document to markdown
2. **File Processor** detects PII using Vault's transform engine
3. **Vault** tokenizes sensitive data
4. **Clean document** is stored in the knowledge base

### 3. Results
- **Original document**: Contains real-looking PII data
- **Processed document**: PII replaced with secure tokens
- **Knowledge base**: Stores only sanitized content
- **AI queries**: Return clean, safe information

## Demo Files

### Before Processing
- **File**: `pii-demo-before.md`
- **Content**: Sample employee data with PII
- **Purpose**: Shows what users might upload

### After Processing  
- **File**: `pii-demo-after.md`
- **Content**: Same document with PII tokenized
- **Purpose**: Shows what gets stored safely

## Testing the Transform Engine

### Manual Testing
```bash
# Test SSN tokenization
curl -X POST \
  -H "X-Vault-Token: YOUR_TOKEN" \
  -d '{"value": "123-45-6789"}' \
  http://VAULT_IP:8200/v1/transform/encode/file-processor/pii

# Test email tokenization  
curl -X POST \
  -H "X-Vault-Token: YOUR_TOKEN" \
  -d '{"value": "user@domain.com"}' \
  http://VAULT_IP:8200/v1/transform/encode/file-processor/pii
```

### Expected Results
- **Input**: `123-45-6789`
- **Output**: `tok_a1b2c3d4e5f6` (or similar secure token)

## Key Benefits Demonstrated

1. **Automatic Detection**: Vault finds PII without manual configuration
2. **Secure Tokenization**: Sensitive data becomes unreadable tokens
3. **Pattern Recognition**: Detects SSN, email, phone, and bank account formats
4. **Integration**: Works seamlessly with your document processing pipeline
5. **Compliance**: Helps meet data protection requirements

## Workshop Discussion Points

- **Why tokenization over masking?** (Security, reversibility, pattern elimination)
- **What types of PII should be protected?** (Legal, ethical, business requirements)
- **How does this improve AI training?** (No data leakage, better model security)
- **What are the trade-offs?** (Complexity vs. security, performance considerations)

## Next Steps

- **Custom Patterns**: Add domain-specific PII detection rules
- **Advanced Tokenization**: Implement reversible tokens for authorized users
- **Audit Logging**: Track all PII operations for compliance
- **Performance Optimization**: Batch processing for large document sets

---
*This demo showcases HashiCorp Vault's enterprise-grade data protection capabilities in a simple, understandable format.*
