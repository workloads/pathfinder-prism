# AI Pipeline Workshop Guide

## Overview

This workshop demonstrates how to build a complete AI document processing system using Azure infrastructure and HashiCorp Nomad.

## Architecture Components

### Infrastructure
- **Azure VMs**: Ubuntu 22.04 LTS with Nomad
- **Azure Blob Storage**: Document storage and processing
- **Azure AD**: OIDC authentication
- **Network Security**: Segmented subnets and security groups

### Applications
- **Ollama**: Local AI model inference
- **OpenWebUI**: AI chat interface with knowledge base
- **File Processor**: DocLings-based document processing
- **Web Upload App**: File upload interface

## Workflow

1. **Document Upload**: Users upload documents via web interface
2. **Storage**: Documents stored in Azure Blob Storage
3. **Processing**: File processor extracts and processes documents
4. **Knowledge Base**: Processed content added to OpenWebUI knowledge base
5. **AI Interaction**: Users can ask questions about uploaded documents

## Key Features

- **OIDC Authentication**: Secure Azure AD integration
- **RAG System**: Retrieval-Augmented Generation for document Q&A
- **Multi-format Support**: PDF, DOCX, TXT, Markdown
- **Scalable Architecture**: Nomad-based container orchestration

## Learning Objectives

- Infrastructure as Code with Terraform
- Container orchestration with Nomad
- AI/ML integration with local models
- Security best practices with OIDC
- Document processing pipelines 