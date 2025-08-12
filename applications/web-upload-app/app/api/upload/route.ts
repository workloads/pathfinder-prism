import { NextRequest, NextResponse } from 'next/server'
import { BlobServiceClient } from '@azure/storage-blob'

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File
    const knowledgeBase = formData.get('knowledgeBase') as string || 'default'
    
    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 })
    }

    // Get Azure Storage configuration
    const storageAccount = process.env.AZURE_STORAGE_ACCOUNT
    const storageKey = process.env.AZURE_STORAGE_ACCESS_KEY
    const uploadContainer = process.env.UPLOAD_CONTAINER || 'uploads'

    if (!storageAccount || !storageKey) {
      return NextResponse.json({ error: 'Storage configuration missing' }, { status: 500 })
    }

    // Create blob service client
    const connectionString = `DefaultEndpointsProtocol=https;AccountName=${storageAccount};AccountKey=${storageKey};EndpointSuffix=core.windows.net`
    const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString)
    
    // Create virtual directory structure in uploads container
    let blobName: string
    if (knowledgeBase === 'default') {
      // Root level file
      blobName = `${Date.now()}-${file.name}`
    } else {
      // Create virtual directory structure: knowledgeBase/filename
      blobName = `${knowledgeBase}/${Date.now()}-${file.name}`
    }
    
    // Upload to uploads container with virtual directory structure
    const uploadContainerClient = blobServiceClient.getContainerClient(uploadContainer)
    const blockBlobClient = uploadContainerClient.getBlockBlobClient(blobName)
    
    // Convert file to buffer and upload
    const arrayBuffer = await file.arrayBuffer()
    const buffer = Buffer.from(arrayBuffer)
    
    await blockBlobClient.upload(buffer, buffer.length, {
      blobHTTPHeaders: {
        blobContentType: file.type,
      },
      metadata: {
        originalName: file.name,
        knowledgeBase: knowledgeBase,
        uploadTime: new Date().toISOString(),
        status: 'uploaded',
        virtualPath: knowledgeBase === 'default' ? undefined : knowledgeBase
      }
    })

    // Also upload to the appropriate knowledge base folder for organization
    if (knowledgeBase !== 'default') {
      try {
        const kbContainerClient = blobServiceClient.getContainerClient('knowledge-base')
        const kbBlobName = `${knowledgeBase}/${Date.now()}-${file.name}`
        const kbBlockBlobClient = kbContainerClient.getBlockBlobClient(kbBlobName)
        
        await kbBlockBlobClient.upload(buffer, buffer.length, {
          blobHTTPHeaders: {
            blobContentType: file.type,
          },
          metadata: {
            originalName: file.name,
            knowledgeBase: knowledgeBase,
            uploadTime: new Date().toISOString(),
            status: 'uploaded',
            sourceBlob: blobName,
            virtualPath: knowledgeBase
          }
        })
      } catch (error) {
        console.warn(`Failed to upload to knowledge base folder ${knowledgeBase}:`, error)
        // Continue anyway - the file is still in uploads container
      }
    }

    return NextResponse.json({ 
      success: true, 
      message: 'File uploaded successfully',
      blobName,
      knowledgeBase,
      fileSize: file.size,
      fileType: file.type,
      virtualPath: knowledgeBase === 'default' ? undefined : knowledgeBase
    })
    
  } catch (error) {
    console.error('Upload error:', error)
    return NextResponse.json({ error: 'Upload failed' }, { status: 500 })
  }
} 