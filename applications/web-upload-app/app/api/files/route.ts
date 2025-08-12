import { NextRequest, NextResponse } from 'next/server'
import { BlobServiceClient } from '@azure/storage-blob'

interface FileInfo {
  id: string
  name: string
  size: number
  type: string
  status: 'uploaded' | 'processing' | 'processed' | 'error'
  uploadTime: Date
  processTime?: Date
  knowledgeBase: string
  blobName: string
  container: string
  message?: string
}

export async function GET(request: NextRequest) {
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

    const files: FileInfo[] = []
    
    // Only scan the processed container for protected files
    const containerName = 'processed'
    
    try {
      const containerClient = blobServiceClient.getContainerClient(containerName)
      
      // List all blobs in the container
      for await (const blob of containerClient.listBlobsFlat()) {
        // Skip directory markers (empty blobs ending with /)
        if (blob.name.endsWith('/') && blob.properties.contentLength === 0) {
          continue
        }
        
        // Only include files that have 'protected_' in their filename (not just at the beginning)
        // This handles virtual paths like: test/protected_file.txt.md
        const filename = blob.name.split('/').pop() || ''
        if (!filename.startsWith('protected_')) {
          console.log(`Skipping file without 'protected_' prefix: ${blob.name}`)
          continue
        }
        
        // Skip metadata files
        if (blob.name.includes('metadata_') || blob.name.endsWith('.json')) {
          console.log(`Skipping metadata file: ${blob.name}`)
          continue
        }
        
        console.log(`Processing protected file: ${blob.name}`)
        
        // Determine knowledge base from blob path or metadata
        let knowledgeBase = 'default'
        let virtualPath: string | undefined
        
        if (blob.metadata?.knowledgeBase) {
          knowledgeBase = blob.metadata.knowledgeBase
        } else if (blob.name.includes('/')) {
          // Extract knowledge base from virtual path
          const pathParts = blob.name.split('/')
          if (pathParts.length > 1) {
            knowledgeBase = pathParts[0]
            virtualPath = pathParts[0]
          }
        }
        
        console.log(`File ${blob.name} assigned to knowledge base: ${knowledgeBase}`)
        
        // Helper function to safely create dates
        const createSafeDate = (dateValue: any): Date => {
          try {
            if (!dateValue) return new Date()
            
            const date = new Date(dateValue)
            if (isNaN(date.getTime())) {
              return new Date()
            }
            return date
          } catch (error) {
            console.warn(`Invalid date value: ${dateValue}, using current date`)
            return new Date()
          }
        }
        
        const fileInfo: FileInfo = {
          id: `${containerName}-${blob.name}`,
          name: blob.metadata?.originalName || blob.name.split('/').pop() || blob.name,
          size: blob.properties.contentLength || 0,
          type: blob.properties.contentType || 'application/octet-stream',
          status: 'processed' as const, // All files from processed container are processed
          uploadTime: createSafeDate(blob.metadata?.uploadTime || blob.properties.createdOn),
          processTime: blob.metadata?.processTime ? createSafeDate(blob.metadata.processTime) : undefined,
          knowledgeBase: knowledgeBase,
          blobName: blob.name,
          container: containerName,
          message: `Document processed and added to ${knowledgeBase} knowledge base`
        }
        files.push(fileInfo)
      }
    } catch (error) {
      console.warn(`Failed to list blobs in container ${containerName}:`, error)
    }

    // Sort files by upload time (newest first)
    files.sort((a, b) => b.uploadTime.getTime() - a.uploadTime.getTime())

    // Log the final file list for debugging
    console.log('Final files list:')
    files.forEach(file => {
      console.log(`  - ${file.blobName} -> KB: ${file.knowledgeBase}`)
    })

    return NextResponse.json(files)
    
  } catch (error) {
    console.error('Files listing error:', error)
    return NextResponse.json({ error: 'Failed to list files' }, { status: 500 })
  }
}
