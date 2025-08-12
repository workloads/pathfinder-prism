FROM python:3.11-slim

# Install system dependencies for Docling
RUN apt-get update && apt-get install -y \
    curl \
    tesseract-ocr \
    tesseract-ocr-eng \
    poppler-utils \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY process_documents.py .
COPY health_server.py .

# Start both the health server and the processor
CMD ["sh", "-c", "python health_server.py & python process_documents.py"] 