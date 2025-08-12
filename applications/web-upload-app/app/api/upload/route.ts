import { NextRequest, NextResponse } from 'next/server'
import { BlobServiceClient } from '@azure/storage-blob'

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File
    
    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 })
    }

    // Get Azure Storage configuration
    const storageAccount = process.env.AZURE_STORAGE_ACCOUNT
    const storageKey = process.env.AZURE_STORAGE_ACCESS_KEY
    const containerName = process.env.UPLOAD_CONTAINER || 'uploads'

    if (!storageAccount || !storageKey) {
      return NextResponse.json({ error: 'Storage configuration missing' }, { status: 500 })
    }

    // Create blob service client
    const connectionString = `DefaultEndpointsProtocol=https;AccountName=${storageAccount};AccountKey=${storageKey};EndpointSuffix=core.windows.net`
    const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString)
    const containerClient = blobServiceClient.getContainerClient(containerName)
    
    // Create blob client
    const blobName = `${Date.now()}-${file.name}`
    const blockBlobClient = containerClient.getBlockBlobClient(blobName)
    
    // Convert file to buffer and upload
    const arrayBuffer = await file.arrayBuffer()
    const buffer = Buffer.from(arrayBuffer)
    
    await blockBlobClient.upload(buffer, buffer.length, {
      blobHTTPHeaders: {
        blobContentType: file.type,
      }
    })

    return NextResponse.json({ 
      success: true, 
      message: 'File uploaded successfully',
      blobName 
    })
    
  } catch (error) {
    console.error('Upload error:', error)
    return NextResponse.json({ error: 'Upload failed' }, { status: 500 })
  }
} 