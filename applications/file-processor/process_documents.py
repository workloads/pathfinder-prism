#!/usr/bin/env python3
"""
File Processor with Dual Vault PII Protection

This application supports two approaches to PII protection:

1. Vault Transform Engine (Enterprise Feature) - Commented out
   - Uses Vault's built-in transformation capabilities
   - Requires Vault Enterprise license
   - More secure and performant

2. Vault KV + Custom Logic (Open Source Compatible) - Active
   - Stores PII patterns securely in Vault KV
   - Applies transformations using Python logic
   - Works with Vault Open Source
   - Configurable patterns without code changes

To switch to Transform Engine:
1. Uncomment vault_client initialization
2. Comment out vault_kv_client initialization
3. Update protect_pii_with_vault() function
"""

import os
import time
import requests
import sys
import logging
import re
from azure.storage.blob import BlobServiceClient
from datetime import datetime
import json
from docling.document_converter import DocumentConverter

# Configure logging to write to stdout and stderr
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.StreamHandler(sys.stderr)
    ]
)
logger = logging.getLogger(__name__)

# Configuration
AZURE_STORAGE_ACCOUNT = os.getenv('AZURE_STORAGE_ACCOUNT')
AZURE_STORAGE_ACCESS_KEY = os.getenv('AZURE_STORAGE_ACCESS_KEY')
OPENWEBUI_URL = os.getenv('OPENWEBUI_URL')
OPENWEBUI_API_KEY = os.getenv('OPENWEBUI_API_KEY')
UPLOAD_CONTAINER = os.getenv('UPLOAD_CONTAINER', 'uploads')
PROCESSED_CONTAINER = os.getenv('PROCESSED_CONTAINER', 'processed')
PROCESSING_INTERVAL = int(os.getenv('PROCESSING_INTERVAL', '30'))
KNOWLEDGE_BASE_NAME = os.getenv('KNOWLEDGE_BASE_NAME', 'Document Processing Pipeline')
KNOWLEDGE_BASE_DESCRIPTION = os.getenv('KNOWLEDGE_BASE_DESCRIPTION', 'Knowledge base for processed documents from the upload pipeline')

# Vault Configuration
VAULT_ADDR = os.getenv('VAULT_ADDR', 'http://localhost:8200')
VAULT_TOKEN = os.getenv('VAULT_TOKEN')
VAULT_TRANSFORM_PATH = os.getenv('VAULT_TRANSFORM_PATH', 'ai_data_transform')
VAULT_ROLE = os.getenv('VAULT_ROLE', 'file-processor')

# Initialize Azure Blob Service Client
connection_string = f"DefaultEndpointsProtocol=https;AccountName={AZURE_STORAGE_ACCOUNT};AccountKey={AZURE_STORAGE_ACCESS_KEY};EndpointSuffix=core.windows.net"
blob_service_client = BlobServiceClient.from_connection_string(connection_string)

class VaultTransformClient:
    """Client for interacting with Vault Transform Engine (Enterprise Feature)"""
    
    def __init__(self, vault_url, token, transform_path, role):
        self.vault_url = vault_url.rstrip('/')
        self.token = token
        self.transform_path = transform_path
        self.role = role
        self.headers = {"X-Vault-Token": token}
        
    def is_available(self):
        """Check if Vault is available"""
        try:
            response = requests.get(f"{self.vault_url}/v1/sys/health", timeout=5)
            return response.status_code == 200
        except Exception:
            return False
    
    def tokenize_pii(self, text):
        """Tokenize sensitive data (SSN, email) using Vault Transform Engine"""
        if not self.is_available():
            logger.warning("Vault not available, using fallback tokenization")
            return self._fallback_tokenization(text)
        
        try:
            # Split text into manageable chunks (Vault has limits)
            chunks = self._split_text_into_chunks(text, max_length=1000)
            processed_chunks = []
            
            for chunk in chunks:
                response = requests.post(
                    f"{self.vault_url}/v1/{self.transform_path}/encode/{self.role}/pii-tokenize",
                    headers=self.headers,
                    json={"value": chunk},
                    timeout=10
                )
                
                if response.status_code == 200:
                    processed_chunks.append(response.json()["data"]["encoded_value"])
                else:
                    logger.warning(f"Vault tokenization failed for chunk: {response.status_code}")
                    processed_chunks.append(chunk)
            
            return " ".join(processed_chunks)
            
        except Exception as e:
            logger.error(f"Error in Vault tokenization: {str(e)}")
            return self._fallback_tokenization(text)
    
    def mask_pii(self, text):
        """Mask sensitive data (phone, bank account) using Vault Transform Engine"""
        if not self.is_available():
            logger.warning("Vault not available, using fallback masking")
            return self._fallback_masking(text)
        
        try:
            response = requests.post(
                f"{self.vault_url}/v1/{self.transform_path}/encode/{self.role}/pii-mask",
                headers=self.headers,
                json={"value": text},
                timeout=10
            )
            
            if response.status_code == 200:
                return response.json()["data"]["encoded_value"]
            else:
                logger.warning(f"Vault masking failed: {response.status_code}")
                return self._fallback_masking(text)
                
        except Exception as e:
            logger.error(f"Error in Vault masking: {str(e)}")
            return self._fallback_masking(text)
    
    def _fallback_tokenization(self, text):
        """Fallback tokenization using simple patterns"""
        # SSN tokenization
        text = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', 'tok_ssn_xxxxx', text)
        # Email tokenization
        text = re.sub(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b', 'tok_email_xxxxx', text)
        return text
    
    def _fallback_masking(self, text):
        """Fallback masking using simple patterns"""
        # Phone masking
        text = re.sub(r'\b\d{3}-\d{3}-\d{4}\b', '***-***-****', text)
        return text
    
    def _split_text_into_chunks(self, text, max_length=1000):
        """Split text into chunks for Vault processing"""
        if len(text) <= max_length:
            return [text]
        
        chunks = []
        current_chunk = ""
        
        for sentence in text.split('.'):
            if len(current_chunk) + len(sentence) < max_length:
                current_chunk += sentence + "."
            else:
                if current_chunk:
                    chunks.append(current_chunk.strip())
                current_chunk = sentence + "."
        
        if current_chunk:
            chunks.append(current_chunk.strip())
        
        return chunks

class VaultKVPIIProtector:
    """Client for PII protection using Vault KV (Open Source Compatible)"""
    
    def __init__(self, vault_url, token):
        self.vault_url = vault_url.rstrip('/')
        self.token = token
        self.headers = {"X-Vault-Token": token}
        
    def is_available(self):
        """Check if Vault is available"""
        try:
            response = requests.get(f"{self.vault_url}/v1/sys/health", timeout=5)
            return response.status_code == 200
        except Exception:
            return False
    
    def get_pii_patterns(self):
        """Securely retrieve PII patterns from Vault KV"""
        try:
            # Get SSN pattern
            response = requests.get(
                f"{self.vault_url}/v1/secret/data/pii-patterns/ssn",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                ssn_pattern = response.json()['data']['data']['pattern']
            else:
                ssn_pattern = r'\b\d{3}-\d{2}-\d{4}\b'  # Fallback pattern
            
            # Get email pattern
            response = requests.get(
                f"{self.vault_url}/v1/secret/data/pii-patterns/email",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                email_pattern = response.json()['data']['data']['pattern']
            else:
                email_pattern = r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'  # Fallback pattern
            
            # Get phone pattern
            response = requests.get(
                f"{self.vault_url}/v1/secret/data/pii-patterns/phone",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                phone_pattern = response.json()['data']['data']['pattern']
            else:
                phone_pattern = r'\b\d{3}-\d{3}-\d{4}\b'  # Fallback pattern
            
            # Get bank pattern
            response = requests.get(
                f"{self.vault_url}/v1/secret/data/pii-patterns/bank",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                bank_pattern = response.json()['data']['data']['pattern']
            else:
                bank_pattern = r'\b\d{4}-\d{4}-\d{4}-\d{4}\b'  # Fallback pattern
            
            return {
                'ssn': ssn_pattern,
                'email': email_pattern,
                'phone': phone_pattern,
                'bank': bank_pattern
            }
            
        except Exception as e:
            logger.warning(f"Error retrieving PII patterns from Vault: {str(e)}")
            return self._fallback_patterns()
    
    def get_replacement_strategies(self):
        """Get how to replace each PII type"""
        try:
            # Get SSN strategy
            response = requests.get(
                f"{self.vault_url}/v1/secret/data/pii-replacements/ssn",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                ssn_strategy = response.json()['data']['data']
            else:
                ssn_strategy = {'method': 'tokenize', 'prefix': 'tok_ssn_'}
            
            # Get phone strategy
            response = requests.get(
                f"{self.vault_url}/v1/secret/data/pii-replacements/phone",
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code == 200:
                phone_strategy = response.json()['data']['data']
            else:
                phone_strategy = {'method': 'mask', 'pattern': '***-***-****'}
            
            return {
                'ssn': ssn_strategy,
                'phone': phone_strategy
            }
            
        except Exception as e:
            logger.warning(f"Error retrieving replacement strategies from Vault: {str(e)}")
            return self._fallback_strategies()
    
    def _fallback_patterns(self):
        """Fallback patterns if Vault is unavailable"""
        return {
            'ssn': r'\b\d{3}-\d{2}-\d{4}\b',
            'email': r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b',
            'phone': r'\b\d{3}-\d{3}-\d{4}\b',
            'bank': r'\b\d{4}-\d{4}-\d{4}-\d{4}\b'
        }
    
    def _fallback_strategies(self):
        """Fallback strategies if Vault is unavailable"""
        return {
            'ssn': {'method': 'tokenize', 'prefix': 'tok_ssn_'},
            'phone': {'method': 'mask', 'pattern': '***-***-****'}
        }
    
    def protect_pii(self, text):
        """Protect PII using patterns stored in Vault KV"""
        try:
            # Get patterns and strategies from Vault
            patterns = self.get_pii_patterns()
            strategies = self.get_replacement_strategies()
            
            protected_text = text
            
            # Apply SSN protection
            if 'ssn' in patterns:
                ssn_pattern = patterns['ssn']
                ssn_strategy = strategies['ssn']
                
                if ssn_strategy['method'] == 'tokenize':
                    # Generate secure token
                    protected_text = re.sub(
                        ssn_pattern, 
                        lambda m: f"tok_ssn_{self._generate_secure_token()}", 
                        protected_text
                    )
            
            # Apply email protection
            if 'email' in patterns:
                email_pattern = patterns['email']
                protected_text = re.sub(
                    email_pattern,
                    lambda m: f"tok_email_{self._generate_secure_token()}", 
                    protected_text
                )
            
            # Apply phone masking
            if 'phone' in patterns:
                phone_pattern = patterns['phone']
                protected_text = re.sub(
                    phone_pattern,
                    "***-***-****",
                    protected_text
                )
            
            # Apply bank account masking
            if 'bank' in patterns:
                bank_pattern = patterns['bank']
                protected_text = re.sub(
                    bank_pattern,
                    "****-****-****-****",
                    protected_text
                )
            
            return protected_text
            
        except Exception as e:
            logger.error(f"Error in Vault KV PII protection: {str(e)}")
            return self._fallback_protection(text)
    
    def _generate_secure_token(self):
        """Generate a secure random token"""
        import secrets
        return secrets.token_hex(6)  # 12 character hex string
    
    def _fallback_protection(self, text):
        """Fallback PII protection if Vault KV fails"""
        # Simple regex-based protection
        text = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', 'tok_ssn_xxxxx', text)
        text = re.sub(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b', 'tok_email_xxxxx', text)
        text = re.sub(r'\b\d{3}-\d{3}-\d{4}\b', '***-***-****', text)
        text = re.sub(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b', '****-****-****-****', text)
        return text

# Initialize Vault clients
# Comment out Transform Engine client (Enterprise feature)
# vault_client = VaultTransformClient(VAULT_ADDR, VAULT_TOKEN, VAULT_TRANSFORM_PATH, VAULT_ROLE) if VAULT_TOKEN else None

# Use KV-based PII protection (Open Source compatible)
# This approach works with Vault Community Edition and stores PII patterns securely
vault_kv_client = VaultKVPIIProtector(VAULT_ADDR, VAULT_TOKEN) if VAULT_TOKEN else None

def list_blobs(container_name):
    """List all blobs in a container"""
    container_client = blob_service_client.get_container_client(container_name)
    return [blob.name for blob in container_client.list_blobs()]

def download_blob(container_name, blob_name, local_path):
    """Download a blob to local storage"""
    container_client = blob_service_client.get_container_client(container_name)
    blob_client = container_client.get_blob_client(blob_name)
    
    with open(local_path, "wb") as file:
        download_stream = blob_client.download_blob()
        file.write(download_stream.readall())

def upload_blob(container_name, blob_name, local_path):
    """Upload a file to blob storage"""
    container_client = blob_service_client.get_container_client(container_name)
    blob_client = container_client.get_blob_client(blob_name)
    
    with open(local_path, "rb") as data:
        blob_client.upload_blob(data, overwrite=True)

def get_list_knowledge() -> list[dict]:
    """Get list of knowledge bases from OpenWebUI"""
    url = f'{OPENWEBUI_URL}/api/v1/knowledge/'
    headers = {
        'Authorization': f'Bearer {OPENWEBUI_API_KEY}',
        'Content-Type': 'application/json'
    }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        knowledge_list = []
        for knowledge in response.json():
            knowledge_list.append({
                'id': knowledge['id'], 
                'name': knowledge['name'], 
                'description': knowledge['description']
            })
        return knowledge_list
    else:
        logger.error(f"Failed to get knowledge bases. Response status code: {response.status_code}")
        return []

def create_knowledge(name: str = None, description: str = None, data: dict = {}, access_control: dict = {}):
    """Create a new knowledge base in OpenWebUI"""
    if name is None:
        name = KNOWLEDGE_BASE_NAME
    if description is None:
        description = KNOWLEDGE_BASE_DESCRIPTION
        
    url = f"{OPENWEBUI_URL}/api/v1/knowledge/create"
    headers = {
        'Authorization': f'Bearer {OPENWEBUI_API_KEY}',
        'Content-Type': 'application/json'
    }
    payload = {
        "name": name,
        "description": description,
        "data": data,
        "access_control": access_control
    }
    
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code == 200:
        logger.info(f"Successfully created knowledge base: {name}")
        return response.json()
    else:
        logger.error(f"Failed to create knowledge base. Status code: {response.status_code}")
        return None

def get_or_create_knowledge_base():
    """Get existing knowledge base or create a new one"""
    knowledge_bases = get_list_knowledge()
    
    # Look for existing knowledge base with our name
    for kb in knowledge_bases:
        if kb['name'] == KNOWLEDGE_BASE_NAME:
            logger.info(f"Found existing knowledge base: {kb['name']} (ID: {kb['id']})")
            return kb['id']
    
    # Create new knowledge base if none exists
    logger.info(f"No existing knowledge base found. Creating new one: {KNOWLEDGE_BASE_NAME}")
    result = create_knowledge()
    if result and 'id' in result:
        return result['id']
    else:
        logger.error("Failed to create knowledge base")
        return None

def upload_file_to_openwebui(file_path: str, file_name: str):
    """Upload a file to OpenWebUI"""
    url = f'{OPENWEBUI_URL}/api/v1/files/'
    headers = {
        'Authorization': f'Bearer {OPENWEBUI_API_KEY}',
        'Accept': 'application/json'
    }
    
    try:
        with open(file_path, 'rb') as file:
            files = {'file': (file_name, file, 'application/octet-stream')}
            response = requests.post(url, headers=headers, files=files)
            
        if response.status_code == 200:
            result = response.json()
            logger.info(f"Successfully uploaded file to OpenWebUI: {file_name}")
            return result.get('id')
        else:
            logger.error(f"Failed to upload file to OpenWebUI. Status code: {response.status_code}")
            return None
    except Exception as e:
        logger.error(f"Error uploading file to OpenWebUI: {str(e)}")
        return None

def add_file_to_knowledge_base(file_id: str, knowledge_base_id: str):
    """Add a file to a knowledge base"""
    url = f'{OPENWEBUI_URL}/api/v1/knowledge/{knowledge_base_id}/file/add'
    headers = {
        'Authorization': f'Bearer {OPENWEBUI_API_KEY}',
        'Content-Type': 'application/json'
    }
    payload = {'file_id': file_id}
    
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code == 200:
        logger.info(f"Successfully added file to knowledge base")
        return True
    else:
        logger.error(f"Failed to add file to knowledge base. Status code: {response.status_code}")
        return False

def convert_document_to_markdown(file_path: str, file_name: str) -> str:
    """Convert document to markdown using Docling with fallback to text processing"""
    try:
        logger.info(f"Converting document to markdown: {file_name}")
        
        # Get file extension for better format handling
        file_ext = file_name.lower().split('.')[-1] if '.' in file_name else ''
        
        # Initialize Docling converter
        converter = DocumentConverter()
        
        # Try to convert with automatic format detection
        try:
            result = converter.convert(file_path)
            markdown_content = result.document.export_to_markdown()
            logger.info(f"Successfully converted {file_name} to markdown using Docling ({len(markdown_content)} characters)")
            return markdown_content
            
        except Exception as format_error:
            logger.warning(f"Docling format detection failed: {str(format_error)}")
            
            # Fallback: Handle different file types manually
            if file_ext in ['txt', 'md', 'markdown']:
                # Plain text files - read and convert to markdown
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Convert to simple markdown
                    markdown_content = f"# {file_name}\n\n{content}"
                    logger.info(f"Converted {file_name} as plain text to markdown ({len(markdown_content)} characters)")
                    return markdown_content
                    
                except Exception as text_error:
                    logger.error(f"Failed to read text file: {str(text_error)}")
                    raise text_error
                    
            elif file_ext in ['json', 'xml']:
                # Structured files - try to extract text content
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # For structured files, create a more organized markdown
                    markdown_content = f"# {file_name}\n\n## Content\n\n```{file_ext}\n{content}\n```\n\n*Converted from {file_ext.upper()} format*"
                    logger.info(f"Converted {file_name} from {file_ext} to markdown ({len(markdown_content)} characters)")
                    return markdown_content
                    
                except Exception as struct_error:
                    logger.error(f"Failed to read structured file: {str(struct_error)}")
                    raise struct_error
                    
            else:
                # Unknown format - try to read as text anyway
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    markdown_content = f"# {file_name}\n\n## Raw Content\n\n```\n{content}\n```\n\n*Converted from unknown format*"
                    logger.info(f"Converted {file_name} from unknown format to markdown ({len(markdown_content)} characters)")
                    return markdown_content
                    
                except Exception as unknown_error:
                    logger.error(f"Failed to read file with unknown format: {str(unknown_error)}")
                    raise format_error
        
    except Exception as e:
        logger.error(f"Error converting document to markdown: {str(e)}")
        return None

def protect_pii_with_vault(content: str) -> tuple[str, dict]:
    """Protect PII using Vault KV patterns (Open Source compatible)"""
    
    # Try KV-based protection first (Open Source compatible)
    if vault_kv_client:
        try:
            logger.info("Protecting PII using Vault KV patterns")
            protected_content = vault_kv_client.protect_pii(content)
            
            # Count PII items for summary
            pii_summary = {
                "vault_used": True,
                "protection_method": "vault_kv",
                "ssn_count": len(re.findall(r'\b\d{3}-\d{2}-\d{4}\b', content)),
                "email_count": len(re.findall(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b', content)),
                "phone_count": len(re.findall(r'\b\d{3}-\d{3}-\d{4}\b', content)),
                "bank_count": len(re.findall(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b', content)),
                "total_pii_items": 0
            }
            pii_summary["total_pii_items"] = sum([
                pii_summary["ssn_count"], 
                pii_summary["email_count"], 
                pii_summary["phone_count"], 
                pii_summary["bank_count"]
            ])
            
            logger.info(f"PII protection completed: {pii_summary['total_pii_items']} items protected using Vault KV")
            return protected_content, pii_summary
            
        except Exception as e:
            logger.error(f"Error in Vault KV PII protection: {str(e)}")
            # Fall through to fallback
    
    # Fallback to basic protection
    logger.warning("Vault KV client not available, using basic PII protection")
    return _basic_pii_protection(content), {"vault_used": False, "protection_method": "basic"}

def _basic_pii_protection(content: str) -> str:
    """Basic PII protection using hardcoded patterns"""
    protected_content = content
    
    # SSN tokenization
    protected_content = re.sub(r'\b\d{3}-\d{2}-\d{4}\b', 'tok_ssn_xxxxx', protected_content)
    
    # Email tokenization
    protected_content = re.sub(r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b', 'tok_email_xxxxx', protected_content)
    
    # Phone masking
    protected_content = re.sub(r'\b\d{3}-\d{3}-\d{4}\b', '***-***-****', protected_content)
    
    # Bank account masking
    protected_content = re.sub(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b', '****-****-****-****', protected_content)
    
    return protected_content

def process_document(file_path, file_name):
    """Process a document using Docling and OpenWebUI knowledge base with Vault PII protection"""
    try:
        logger.info(f"Processing document: {file_name}")
        
        # Convert document to markdown using Docling
        markdown_content = convert_document_to_markdown(file_path, file_name)
        if not markdown_content:
            logger.error(f"Failed to convert document to markdown: {file_name}")
            return False
        
        # Save original markdown to temporary file
        original_markdown_path = f"/tmp/original_{file_name}.md"
        with open(original_markdown_path, "w", encoding="utf-8") as f:
            f.write(markdown_content)
        
        # Protect PII using Vault Transform Engine
        protected_content, pii_summary = protect_pii_with_vault(markdown_content)
        
        # Save protected markdown to temporary file
        protected_markdown_path = f"/tmp/protected_{file_name}.md"
        with open(protected_markdown_path, "w", encoding="utf-8") as f:
            f.write(protected_content)
        
        # Get or create knowledge base
        knowledge_base_id = get_or_create_knowledge_base()
        if not knowledge_base_id:
            logger.error(f"Failed to get or create knowledge base for {file_name}")
            return False
        
        # Upload protected version to processed container (secure)
        protected_file_name = f"protected_{file_name}.md"
        upload_blob(PROCESSED_CONTAINER, protected_file_name, protected_markdown_path)
        
        # Upload protected version to OpenWebUI for knowledge base
        file_id = upload_file_to_openwebui(protected_markdown_path, protected_file_name)
        if not file_id:
            logger.error(f"Failed to upload protected markdown file to OpenWebUI: {protected_file_name}")
            return False
        
        # Add file to knowledge base
        if not add_file_to_knowledge_base(file_id, knowledge_base_id):
            logger.error(f"Failed to add protected markdown file to knowledge base: {protected_file_name}")
            return False
        
        # Create enhanced metadata with PII protection details
        metadata = {
            "original_file": file_name,
            "protected_markdown": protected_file_name,
            "openwebui_file_id": file_id,
            "knowledge_base_id": knowledge_base_id,
            "original_length": len(markdown_content),
            "protected_length": len(protected_content),
            "pii_protection": pii_summary,
            "processed_at": datetime.utcnow().isoformat(),
            "status": "completed_with_pii_protection"
        }
        
        metadata_file = f"metadata_{file_name}.json"
        with open("/tmp/metadata.json", "w") as f:
            json.dump(metadata, f, indent=2)
        
        # Store metadata in processed container
        upload_blob(PROCESSED_CONTAINER, metadata_file, "/tmp/metadata.json")
        
        # Clean up temporary files
        for temp_file in [original_markdown_path, protected_markdown_path]:
            if os.path.exists(temp_file):
                os.remove(temp_file)
        
        logger.info(f"Successfully processed document with PII protection: {file_name}")
        logger.info(f"PII Summary: {pii_summary['total_pii_items']} items protected using {pii_summary['protection_method']}")
        return True
        
    except Exception as e:
        logger.error(f"Error processing {file_name}: {str(e)}")
        return False


def get_document_comparison(file_name: str) -> dict:
    """Get protected version and metadata for demo comparison"""
    try:
        # Get protected version from processed container
        protected_file_name = f"protected_{file_name}.md"
        protected_content = ""
        try:
            container_client = blob_service_client.get_container_client(PROCESSED_CONTAINER)
            blob_client = container_client.get_blob_client(protected_file_name)
            download_stream = blob_client.download_blob()
            protected_content = download_stream.readall().decode('utf-8')
        except Exception as e:
            logger.warning(f"Could not retrieve protected version: {str(e)}")
        
        # Get metadata for PII summary
        metadata_file = f"metadata_{file_name}.json"
        metadata = {}
        try:
            container_client = blob_service_client.get_container_client(PROCESSED_CONTAINER)
            blob_client = container_client.get_blob_client(metadata_file)
            download_stream = blob_client.download_blob()
            metadata = json.loads(download_stream.readall().decode('utf-8'))
        except Exception as e:
            logger.warning(f"Could not retrieve metadata: {str(e)}")
        
        return {
            "protected": protected_content,
            "metadata": metadata,
            "comparison_available": bool(protected_content)
        }
        
    except Exception as e:
        logger.error(f"Error getting document comparison: {str(e)}")
        return {
            "protected": "",
            "metadata": {},
            "comparison_available": False,
            "error": str(e)
        }


def main():
    """Main processing loop"""
    logger.info("Starting file processor...")
    
    while True:
        try:
            # List files in upload container
            upload_files = list_blobs(UPLOAD_CONTAINER)
            
            for file_name in upload_files:
                if not file_name.endswith('/'):  # Skip directories
                    local_path = f"/tmp/{file_name}"
                    
                    # Download file
                    download_blob(UPLOAD_CONTAINER, file_name, local_path)
                    
                    # Process file
                    if process_document(local_path, file_name):
                        # Delete from upload container after successful processing
                        container_client = blob_service_client.get_container_client(UPLOAD_CONTAINER)
                        blob_client = container_client.get_blob_client(file_name)
                        blob_client.delete_blob()
                        logger.info(f"Successfully processed and removed: {file_name}")
                    
                    # Clean up local file
                    if os.path.exists(local_path):
                        os.remove(local_path)
            
            # Wait before next check
            time.sleep(PROCESSING_INTERVAL)
            
        except Exception as e:
            logger.error(f"Error in main loop: {str(e)}")
            time.sleep(PROCESSING_INTERVAL)

if __name__ == "__main__":
    main() 