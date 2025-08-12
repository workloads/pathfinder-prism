import { NextRequest, NextResponse } from 'next/server'
import { BlobServiceClient } from '@azure/storage-blob'

export async function GET() {
  try {
    // Get Azure Storage configuration
    const storageAccount = process.env.AZURE_STORAGE_ACCOUNT
    const storageKey = process.env.AZURE_STORAGE_ACCESS_KEY

    if (!storageAccount || !storageKey) {
      return NextResponse.json({ error: 'Storage configuration missing' }, { status: 500 })
    }

    // Create blob service client
    const connectionString = `DefaultEndpointsProtocol=https;AccountName=${storageAccount};AccountKey=${storageKey};EndpointSuffix=core.windows.net`
    const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString)

    const knowledgeBases: Array<{ id: string; name: string; path: string; fileCount: number }> = [
      { id: 'default', name: 'Default Knowledge Base', path: 'knowledge-base', fileCount: 0 }
    ]

    // Scan uploads and knowledge-base containers to find existing knowledge bases
    const containers = ['uploads', 'knowledge-base']
    
    for (const containerName of containers) {
      try {
        const containerClient = blobServiceClient.getContainerClient(containerName)
        
        // List all blobs in the container
        for await (const blob of containerClient.listBlobsFlat()) {
          if (blob.name.includes('/')) {
            const pathParts = blob.name.split('/')
            if (pathParts.length > 1) {
              const kbName = pathParts[0]
              
              // Check if this knowledge base already exists in our list
              const existingKB = knowledgeBases.find(kb => kb.id === kbName)
              if (!existingKB) {
                knowledgeBases.push({
                  id: kbName,
                  name: `${kbName.charAt(0).toUpperCase() + kbName.slice(1)} Documents`,
                  path: `knowledge-base/${kbName}`,
                  fileCount: 0
                })
              }
            }
          }
        }
      } catch (error) {
        console.warn(`Failed to list blobs in container ${containerName}:`, error)
      }
    }

    // Count files for each knowledge base
    for (const kb of knowledgeBases) {
      try {
        const processedContainer = blobServiceClient.getContainerClient('processed')
        let count = 0
        
        for await (const blob of processedContainer.listBlobsFlat()) {
          // Only count protected files, exclude metadata
          // Check if the filename (not the full path) starts with 'protected_'
          const filename = blob.name.split('/').pop() || ''
          if (filename.startsWith('protected_') && 
              !blob.name.includes('metadata_') && 
              !blob.name.endsWith('.json')) {
            
            // Check if this file belongs to this knowledge base
            if (kb.id === 'default') {
              // Default knowledge base gets files without virtual paths
              if (!blob.name.includes('/')) {
                count++
              }
            } else {
              // Other knowledge bases get files with their virtual path
              if (blob.name.startsWith(`${kb.id}/`)) {
                count++
              }
            }
          }
        }
        
        kb.fileCount = count
      } catch (error) {
        console.warn(`Failed to count files for knowledge base ${kb.id}:`, error)
      }
    }

    return NextResponse.json(knowledgeBases)
    
  } catch (error) {
    console.error('Knowledge bases listing error:', error)
    return NextResponse.json({ error: 'Failed to list knowledge bases' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const { name } = await request.json()
    
    if (!name || typeof name !== 'string') {
      return NextResponse.json({ error: 'Knowledge base name is required' }, { status: 400 })
    }

    // Get Azure Storage configuration
    const storageAccount = process.env.AZURE_STORAGE_ACCOUNT
    const storageKey = process.env.AZURE_STORAGE_ACCESS_KEY

    if (!storageAccount || !storageKey) {
      return NextResponse.json({ error: 'Storage configuration missing' }, { status: 500 })
    }

    // Create blob service client
    const connectionString = `DefaultEndpointsProtocol=https;AccountName=${storageAccount};AccountKey=${storageKey};EndpointSuffix=core.windows.net`
    const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString)

    const kbId = name.toLowerCase().replace(/\s+/g, '-')
    
    // Create a marker blob in the knowledge-base container to represent the new knowledge base
    const kbContainer = blobServiceClient.getContainerClient('knowledge-base')
    const markerBlob = kbContainer.getBlockBlobClient(`${kbId}/.marker`)
    
    await markerBlob.upload('', 0, {
      metadata: {
        name: name,
        created: new Date().toISOString(),
        type: 'knowledge-base-marker'
      }
    })

    const newKnowledgeBase = {
      id: kbId,
      name: name,
      path: `knowledge-base/${kbId}`,
      fileCount: 0
    }

    return NextResponse.json(newKnowledgeBase)
    
  } catch (error) {
    console.error('Knowledge base creation error:', error)
    return NextResponse.json({ error: 'Failed to create knowledge base' }, { status: 500 })
  }
}
