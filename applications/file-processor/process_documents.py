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
import gc
import psutil
from azure.storage.blob import BlobServiceClient, ContainerClient
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

# Memory monitoring and optimization
def log_memory_usage():
    """Log current memory usage"""
    try:
        process = psutil.Process()
        memory_info = process.memory_info()
        memory_percent = process.memory_percent()
        logger.info(f"Memory usage: {memory_info.rss / 1024 / 1024:.1f} MB ({memory_percent:.1f}%)")
    except Exception as e:
        logger.debug(f"Could not log memory usage: {str(e)}")

def optimize_memory():
    """Force garbage collection and memory optimization"""
    try:
        gc.collect()
        logger.debug("Memory optimization completed")
    except Exception as e:
        logger.debug(f"Memory optimization failed: {str(e)}")

def check_memory_available():
    """Check if we have enough memory available for processing"""
    try:
        memory = psutil.virtual_memory()
        available_gb = memory.available / 1024 / 1024 / 1024
        if available_gb < 1.0:  # Less than 1GB available
            logger.warning(f"Low memory available: {available_gb:.1f} GB")
            optimize_memory()
            return False
        return True
    except Exception as e:
        logger.debug(f"Could not check memory: {str(e)}")
        return True  # Assume OK if we can't check

# Configuration
AZURE_STORAGE_ACCOUNT = os.getenv('AZURE_STORAGE_ACCOUNT')
AZURE_STORAGE_ACCESS_KEY = os.getenv('AZURE_STORAGE_ACCESS_KEY')
OPENWEBUI_URL = os.getenv('OPENWEBUI_URL')
OPENWEBUI_API_KEY = os.getenv('OPENWEBUI_API_KEY')
UPLOAD_CONTAINER = os.getenv('UPLOAD_CONTAINER', 'uploads')
PROCESSED_CONTAINER = os.getenv('PROCESSED_CONTAINER', 'processed')
PROCESSING_INTERVAL = int(os.getenv('PROCESSING_INTERVAL', '30'))
KNOWLEDGE_BASE_NAME = os.getenv('KNOWLEDGE_BASE_NAME', 'Default Knowledge Base')
KNOWLEDGE_BASE_DESCRIPTION = os.getenv('KNOWLEDGE_BASE_DESCRIPTION', 'Knowledge base for processed documents from the upload pipeline')
BASE_MODEL_ID = os.getenv('BASE_MODEL_ID', 'granite-code:latest')  # Base model for new KB agents

# Vault Configuration
VAULT_ADDR = os.getenv('VAULT_ADDR', 'http://localhost:8200')
VAULT_TOKEN = os.getenv('VAULT_TOKEN')
VAULT_TRANSFORM_PATH = os.getenv('VAULT_TRANSFORM_PATH', 'ai_data_transform')
VAULT_ROLE = os.getenv('VAULT_ROLE', 'file-processor')

# Initialize Azure Blob Service Client
connection_string = f"DefaultEndpointsProtocol=https;AccountName={AZURE_STORAGE_ACCOUNT};AccountKey={AZURE_STORAGE_ACCESS_KEY};EndpointSuffix=core.windows.net"
blob_service_client = BlobServiceClient.from_connection_string(connection_string)

class VirtualFileHandler:
    """Handles virtual files and directory structures in Azure Blob Storage"""
    
    def __init__(self, blob_service_client):
        self.blob_service_client = blob_service_client
        
    def is_virtual_directory(self, blob_name):
        """Check if a blob name represents a virtual directory"""
        return blob_name.endswith('/') or '/' in blob_name
        
    def get_virtual_path_components(self, blob_name):
        """Extract virtual path components from blob name"""
        if not self.is_virtual_directory(blob_name):
            return [blob_name]
        
        # Split by forward slash and filter out empty components
        components = [comp for comp in blob_name.split('/') if comp]
        return components
        
    def create_virtual_directory_structure(self, container_name, virtual_path):
        """Create virtual directory structure in target container"""
        # This function is no longer needed since we're not preserving virtual directory structures
        # We only care about organizing files into knowledge bases based on their virtual paths
        pass
    
    def get_virtual_file_metadata(self, blob_client):
        """Extract metadata from virtual file blob"""
        try:
            properties = blob_client.get_blob_properties()
            metadata = {
                'name': blob_client.blob_name,
                'size': properties.size,
                'created': properties.creation_time.isoformat() if properties.creation_time else None,
                'last_modified': properties.last_modified.isoformat() if properties.last_modified else None,
                'content_type': properties.content_settings.content_type,
                'content_encoding': properties.content_settings.content_encoding,
                'content_language': properties.content_settings.content_language,
                'cache_control': properties.content_settings.cache_control,
                'content_disposition': properties.content_settings.content_disposition,
                'content_md5': properties.content_settings.content_md5.hex() if properties.content_settings.content_md5 else None,
                'etag': properties.etag,
                'blob_type': properties.blob_type,
                'access_tier': properties.access_tier,
                'access_tier_inferred': properties.access_tier_inferred,
                'archive_status': properties.archive_status,
                'copy_id': properties.copy_id,
                'copy_status': properties.copy_status,
                'copy_source': properties.copy_source,
                'copy_progress': properties.copy_progress,
                'copy_completion_time': properties.copy_completion_time.isoformat() if properties.copy_completion_time else None,
                'copy_status_description': properties.copy_status_description,
                'server_encrypted': properties.server_encrypted,
                'incremental_copy': properties.incremental_copy,
                'deleted_time': properties.deleted_time.isoformat() if properties.deleted_time else None,
                'remaining_retention_days': properties.remaining_retention_days,
                'access_tier_change_time': properties.access_tier_change_time.isoformat() if properties.access_tier_change_time else None,
                'custom_metadata': properties.metadata
            }
            return metadata
        except Exception as e:
            logger.warning(f"Failed to get virtual file metadata: {str(e)}")
            return {}
    
    def preserve_virtual_structure(self, source_blob_name, target_container, target_prefix=""):
        """Preserve virtual directory structure when moving files"""
        # Virtual file handling is always enabled, so this function is no longer needed
        # The target_prefix is now handled by the caller (process_document)
        return target_prefix + os.path.basename(source_blob_name)
    
    def process_virtual_file_hierarchy(self, container_name, max_depth=None):
        """Process virtual file hierarchy in a container"""
        if max_depth is None:
            max_depth = 5 # Default to 5 levels for virtual structure
            
        try:
            container_client = self.blob_service_client.get_container_client(container_name)
            virtual_structure = {}
            
            for blob in container_client.list_blobs():
                if self.is_virtual_directory(blob.name):
                    # This is a virtual directory or nested file
                    components = self.get_virtual_path_components(blob.name)
                    
                    if len(components) <= max_depth:
                        # Build virtual structure
                        current_level = virtual_structure
                        for i, component in enumerate(components[:-1]):
                            if component not in current_level:
                                current_level[component] = {'type': 'directory', 'children': {}}
                            current_level = current_level[component]['children']
                        
                        # Add the file
                        if components:
                            current_level[components[-1]] = {
                                'type': 'file',
                                'blob_name': blob.name,
                                'size': blob.size,
                                'last_modified': blob.last_modified.isoformat() if blob.last_modified else None
                            }
            
            return virtual_structure
            
        except Exception as e:
            logger.error(f"Error processing virtual file hierarchy: {str(e)}")
            return {}
    
    def get_virtual_file_content(self, blob_client, encoding='utf-8'):
        """Get content from virtual file with proper encoding handling"""
        try:
            properties = blob_client.get_blob_properties()
            content_type = properties.content_settings.content_type or 'application/octet-stream'
            
            # Download blob content
            download_stream = blob_client.download_blob()
            content = download_stream.readall()
            
            # Handle text-based content types
            if content_type.startswith('text/') or content_type in ['application/json', 'application/xml', 'application/javascript']:
                try:
                    return content.decode(encoding)
                except UnicodeDecodeError:
                    # Try different encodings
                    for enc in ['utf-8', 'latin-1', 'cp1252']:
                        try:
                            return content.decode(enc)
                        except UnicodeDecodeError:
                            continue
                    # If all fail, return as bytes
                    return content
            else:
                # Binary content
                return content
                
        except Exception as e:
            logger.error(f"Error getting virtual file content: {str(e)}")
            return None

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
        logger.info(f"Successfully created default knowledge base: {KNOWLEDGE_BASE_NAME} (ID: {result['id']})")
        
        # Automatically create a model and attach this default knowledge base
        model_result = create_model_with_knowledge_base(result['id'], KNOWLEDGE_BASE_NAME)
        if model_result:
            logger.info(f"Successfully created model for default knowledge base: {KNOWLEDGE_BASE_NAME}")
        else:
            logger.warning(f"Failed to create model for default knowledge base: {KNOWLEDGE_BASE_NAME}")
        
        return result['id']
    else:
        logger.error("Failed to create knowledge base")
        return None

def list_models():
    """List all models in OpenWebUI"""
    try:
        if not OPENWEBUI_URL or not OPENWEBUI_API_KEY:
            logger.warning("OpenWebUI not configured, cannot list models")
            return []
            
        url = f'{OPENWEBUI_URL}/api/v1/models/'
        headers = {
            'Authorization': f'Bearer {OPENWEBUI_API_KEY}',
            'Accept': 'application/json'
        }
        
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            models = response.json()
            logger.info(f"Found {len(models)} existing models")
            return models
        else:
            logger.error(f"Failed to list models. Status code: {response.status_code}")
            return []
            
    except Exception as e:
        logger.error(f"Error listing models: {str(e)}")
        return []

def create_model_with_knowledge_base(knowledge_base_id: str, knowledge_base_name: str):
    """Create a new model and attach a knowledge base to it"""
    try:
        # Check if OpenWebUI is configured
        if not OPENWEBUI_URL or not OPENWEBUI_API_KEY:
            logger.warning("OpenWebUI not configured, skipping model creation")
            return None
            
        url = f'{OPENWEBUI_URL}/api/v1/models/create'
        headers = {
            'Authorization': f'Bearer {OPENWEBUI_API_KEY}',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
        
        # Create model name based on knowledge base name
        model_name = f"{knowledge_base_name}-kb-agent"
        model_id = f"kb-agent-{knowledge_base_id[:8]}"  # Use first 8 chars of KB ID for uniqueness
        
        payload = {
            "id": model_id,
            "base_model_id": BASE_MODEL_ID,  # Use the configured base model
            "name": model_name,
            "meta": {
                "profile_image_url": "/static/favicon.png",
                "description": f"AI agent with access to {knowledge_base_name} knowledge base",
                "suggestion_prompts": None,
                "tags": [{"name": "kb-agent"}],
                "capabilities": {
                    "vision": True,
                    "file_upload": True,
                    "web_search": True,
                    "image_generation": True,
                    "code_interpreter": True,
                    "citations": True
                },
                "knowledge": [{
                    "id": knowledge_base_id,
                    "name": knowledge_base_name,
                    "description": f"Knowledge base for {knowledge_base_name} documents from the upload pipeline"
                }]
            },
            "params": {},
            "access_control": None
        }
        
        response = requests.post(url, headers=headers, json=payload)
        if response.status_code == 200:
            result = response.json()
            logger.info(f"Successfully created model '{model_name}' with knowledge base '{knowledge_base_name}'")
            return result
        else:
            logger.error(f"Failed to create model. Status code: {response.status_code}, Response: {response.text}")
            return None
            
    except Exception as e:
        logger.error(f"Error creating model with knowledge base: {str(e)}")
        return None

def get_virtual_path_from_blob_name(blob_name):
    """Extract virtual path from blob name"""
    if '/' not in blob_name:
        return None
    
    # Get the directory path (everything before the filename)
    path_parts = blob_name.split('/')
    if len(path_parts) <= 1:
        return None
    
    # Return the directory path (everything except the filename)
    return '/'.join(path_parts[:-1])

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
        
        # Extract just the filename without virtual path for temporary files
        base_filename = file_name.split('/')[-1] if '/' in file_name else file_name
        
        # Convert document to markdown using Docling
        markdown_content = convert_document_to_markdown(file_path, file_name)
        if not markdown_content:
            logger.error(f"Failed to convert document to markdown: {file_name}")
            return False
        
        # Save original markdown to temporary file (use base filename only)
        original_markdown_path = f"/tmp/original_{base_filename}.md"
        with open(original_markdown_path, "w", encoding="utf-8") as f:
            f.write(markdown_content)
        
        # Protect PII using Vault Transform Engine
        protected_content, pii_summary = protect_pii_with_vault(markdown_content)
        
        # Save protected markdown to temporary file (use base filename only)
        protected_markdown_path = f"/tmp/protected_{base_filename}.md"
        with open(protected_markdown_path, "w", encoding="utf-8") as f:
            f.write(protected_content)
        
        # Determine knowledge base based on virtual path
        virtual_path = get_virtual_path_from_blob_name(file_name)
        knowledge_base_id = get_knowledge_base_for_file(file_name)
        
        if not knowledge_base_id:
            logger.error(f"Failed to get or create knowledge base for {file_name}")
            return False
        
        # Upload protected version to processed container (secure)
        # Preserve virtual path structure: test/file.txt -> test/protected_file.txt.md
        if virtual_path:
            protected_file_name = f"{virtual_path}/protected_{base_filename}.md"
        else:
            protected_file_name = f"protected_{base_filename}.md"
        
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
        
        # Create enhanced metadata with PII protection details and knowledge base info
        metadata = {
            "original_file": file_name,
            "protected_markdown": protected_file_name,
            "openwebui_file_id": file_id,
            "knowledge_base_id": knowledge_base_id,
            "virtual_path": virtual_path,
            "knowledge_base_name": "Default" if not virtual_path else virtual_path.split('/')[0].title(),
            "original_length": len(markdown_content),
            "protected_length": len(protected_content),
            "pii_protection": pii_summary,
            "processed_at": datetime.utcnow().isoformat(),
            "status": "completed_with_pii_protection"
        }
        
        # Preserve virtual path structure for metadata file: test/file.txt -> test/metadata_file.txt.json
        if virtual_path:
            metadata_file = f"{virtual_path}/metadata_{base_filename}.json"
        else:
            metadata_file = f"metadata_{base_filename}.json"
        
        metadata_path = f"/tmp/metadata_{base_filename}.json"
        with open(metadata_path, "w") as f:
            json.dump(metadata, f, indent=2)
        
        # Store metadata in processed container
        upload_blob(PROCESSED_CONTAINER, metadata_file, metadata_path)
        
        # Clean up temporary files
        for temp_file in [original_markdown_path, protected_markdown_path, metadata_path]:
            if os.path.exists(temp_file):
                os.remove(temp_file)
        
        logger.info(f"Successfully processed document with PII protection: {file_name}")
        logger.info(f"PII Summary: {pii_summary['total_pii_items']} items protected using {pii_summary['protection_method']}")
        logger.info(f"Knowledge Base: {metadata['knowledge_base_name']} (ID: {knowledge_base_id})")
        return True
        
    except Exception as e:
        logger.error(f"Error processing {file_name}: {str(e)}")
        return False

def process_virtual_document(blob_name, container_name):
    """Process a virtual document directly from blob storage"""
    try:
        logger.info(f"Processing virtual document: {blob_name}")
        
        # Initialize virtual file handler
        virtual_handler = VirtualFileHandler(blob_service_client)
        
        # Get blob client
        container_client = blob_service_client.get_container_client(container_name)
        blob_client = container_client.get_blob_client(blob_name)
        
        # Get virtual file metadata
        metadata = virtual_handler.get_virtual_file_metadata(blob_client)
        
        # Get virtual file content
        content = virtual_handler.get_virtual_file_content(blob_client)
        if content is None:
            logger.error(f"Failed to get content from virtual file: {blob_name}")
            return False
        
        # Convert content to string if it's bytes
        if isinstance(content, bytes):
            try:
                content = content.decode('utf-8')
            except UnicodeDecodeError:
                # Try other encodings
                for encoding in ['latin-1', 'cp1252']:
                    try:
                        content = content.decode(encoding)
                        break
                    except UnicodeDecodeError:
                        continue
                else:
                    logger.error(f"Failed to decode content from virtual file: {blob_name}")
                    return False
        
        # Save content to temporary file
        temp_file_path = f"/tmp/virtual_{os.path.basename(blob_name)}"
        with open(temp_file_path, "w", encoding="utf-8") as f:
            f.write(content)
        
        # Process the document (this will handle knowledge base creation based on virtual path)
        success = process_document(temp_file_path, blob_name)
        
        # Clean up temporary file
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)
        
        return success
        
    except Exception as e:
        logger.error(f"Error processing virtual document {blob_name}: {str(e)}")
        return False

def get_document_comparison(file_name: str) -> dict:
    """Get protected version and metadata for demo comparison"""
    try:
        # Get protected version from processed container
        # Use virtual path-aware naming: test/file.txt -> test/protected_file.txt.md
        virtual_path = get_virtual_path_from_blob_name(file_name)
        base_filename = file_name.split('/')[-1] if '/' in file_name else file_name
        
        if virtual_path:
            protected_file_name = f"{virtual_path}/protected_{base_filename}.md"
            metadata_file = f"{virtual_path}/metadata_{base_filename}.json"
        else:
            protected_file_name = f"protected_{base_filename}.md"
            metadata_file = f"metadata_{base_filename}.json"
        
        protected_content = ""
        try:
            container_client = blob_service_client.get_container_client(PROCESSED_CONTAINER)
            blob_client = container_client.get_blob_client(protected_file_name)
            download_stream = blob_client.download_blob()
            protected_content = download_stream.readall().decode('utf-8')
        except Exception as e:
            logger.warning(f"Could not retrieve protected version: {str(e)}")
        
        # Get metadata for PII summary
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

def get_knowledge_base_summary():
    """Get summary of all knowledge bases and their file counts"""
    try:
        knowledge_bases = get_list_knowledge()
        summary = []
        
        for kb in knowledge_bases:
            # Get files in this knowledge base
            url = f'{OPENWEBUI_URL}/api/v1/knowledge/{kb["id"]}/files'
            headers = {
                'Authorization': f'Bearer {OPENWEBUI_API_KEY}',
                'Content-Type': 'application/json'
            }
            
            try:
                response = requests.get(url, headers=headers)
                if response.status_code == 200:
                    files = response.json()
                    file_count = len(files)
                else:
                    file_count = 0
            except Exception:
                file_count = 0
            
            summary.append({
                'id': kb['id'],
                'name': kb['name'],
                'description': kb['description'],
                'file_count': file_count
            })
        
        return summary
        
    except Exception as e:
        logger.error(f"Error getting knowledge base summary: {str(e)}")
        return []

def get_knowledge_base_for_file(file_name):
    """Get the appropriate knowledge base for a file based on its virtual path"""
    virtual_path = get_virtual_path_from_blob_name(file_name)
    
    if not virtual_path:
        # Root level file - use default knowledge base
        return get_or_create_knowledge_base()
    
    # Extract the top-level directory
    path_components = [comp for comp in virtual_path.split('/') if comp]
    if not path_components:
        return get_or_create_knowledge_base()
    
    # Use the directory name directly for the knowledge base
    directory_name = path_components[0]
    kb_name = f"{directory_name.title()} Knowledge Base"
    kb_description = f"Knowledge base for {directory_name.title()} documents from the upload pipeline"
    
    # Get or create the knowledge base
    knowledge_bases = get_list_knowledge()
    
    for kb in knowledge_bases:
        if kb['name'] == kb_name:
            logger.debug(f"Found existing knowledge base for {directory_name}: {kb['name']} (ID: {kb['id']})")
            return kb['id']
    
    # Create new knowledge base
    logger.info(f"Creating new knowledge base for {directory_name}: {kb_name}")
    result = create_knowledge(name=kb_name, description=kb_description)
    if result and 'id' in result:
        logger.info(f"Successfully created knowledge base: {kb_name} (ID: {result['id']})")
        
        # Automatically create a model and attach this knowledge base
        model_result = create_model_with_knowledge_base(result['id'], kb_name)
        if model_result:
            logger.info(f"Successfully created model for knowledge base: {kb_name}")
        else:
            logger.warning(f"Failed to create model for knowledge base: {kb_name}")
        
        return result['id']
    else:
        logger.error(f"Failed to create knowledge base for {directory_name}")
        # Fall back to default knowledge base
        return get_or_create_knowledge_base()

def main():
    """Main processing loop with enhanced virtual file handling"""
    logger.info("Starting file processor with virtual file support...")
    logger.info(f"Base model for KB agents: {BASE_MODEL_ID}")
    
    # Initialize virtual file handler
    virtual_handler = VirtualFileHandler(blob_service_client)
    
    # Log current knowledge base status
    kb_summary = get_knowledge_base_summary()
    if kb_summary:
        logger.info("Current knowledge bases:")
        for kb in kb_summary:
            logger.info(f"  - {kb['name']}: {kb['file_count']} files")
    
    # Log current models status
    models = list_models()
    if models:
        logger.info("Current models:")
        for model in models:
            model_name = model.get('name', 'Unknown')
            model_id = model.get('id', 'Unknown')
            logger.info(f"  - {model_name} (ID: {model_id})")
    
    while True:
        try:
            # List files in upload container
            upload_files = list_blobs(UPLOAD_CONTAINER)
            
            # Process virtual file hierarchy if enabled
            # Virtual file handling is always enabled for automatic knowledge base organization
            virtual_structure = virtual_handler.process_virtual_file_hierarchy(UPLOAD_CONTAINER)
            if virtual_structure:
                logger.debug(f"Virtual file structure detected: {json.dumps(virtual_structure, indent=2)}")
            
            for file_name in upload_files:
                if not file_name.endswith('/'):  # Skip directory markers
                    # Extract just the filename without virtual path for local processing
                    base_filename = file_name.split('/')[-1] if '/' in file_name else file_name
                    local_path = f"/tmp/{base_filename}"
                    
                    # Check if this is a virtual file
                    if virtual_handler.is_virtual_directory(file_name):
                        logger.info(f"Processing virtual file: {file_name}")
                        if process_virtual_document(file_name, UPLOAD_CONTAINER):
                            # Delete from upload container after successful processing
                            container_client = blob_service_client.get_container_client(UPLOAD_CONTAINER)
                            blob_client = container_client.get_blob_client(file_name)
                            blob_client.delete_blob()
                            logger.info(f"Successfully processed and removed virtual file: {file_name}")
                    else:
                        # Regular file processing
                        try:
                            # Download file
                            download_blob(UPLOAD_CONTAINER, file_name, local_path)
                            
                            # Process file
                            if process_document(local_path, file_name):
                                # Delete from upload container after successful processing
                                container_client = blob_service_client.get_container_client(UPLOAD_CONTAINER)
                                blob_client = container_client.get_blob_client(file_name)
                                blob_client.delete_blob()
                                logger.info(f"Successfully processed and removed: {file_name}")
                            
                        except Exception as e:
                            logger.error(f"Error processing regular file {file_name}: {str(e)}")
                        finally:
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