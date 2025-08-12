'use client'

import React, { useState, useCallback, useEffect } from 'react'
import { useDropzone } from 'react-dropzone'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader  } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Badge } from '@/components/ui/badge'
import { 
  Upload, 
  FileText, 
  FolderOpen, 
  Plus, 
  RefreshCw, 
  CheckCircle,
  Clock,
  XCircle
} from 'lucide-react'

interface FileStatus {
  id: string
  name: string
  size: number
  type: string
  status: 'uploaded' | 'processing' | 'processed' | 'error'
  knowledgeBase: string
  uploadTime: Date
  processTime?: Date
  message?: string
}

interface KnowledgeBase {
  id: string
  name: string
  path: string
  fileCount: number
}

export default function FileUpload() {
  const [selectedKnowledgeBase, setSelectedKnowledgeBase] = useState('default')
  const [knowledgeBases, setKnowledgeBases] = useState<KnowledgeBase[]>([
    { id: 'default', name: 'Default Knowledge Base', path: 'knowledge-base', fileCount: 0 }
  ])
  const [newKnowledgeBaseName, setNewKnowledgeBaseName] = useState('')
  const [fileStatuses, setFileStatuses] = useState<FileStatus[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [isCreatingKB, setIsCreatingKB] = useState(false)

  // Load selected knowledge base from localStorage on component mount
  useEffect(() => {
    const savedKB = localStorage.getItem('selectedKnowledgeBase')
    if (savedKB) {
      setSelectedKnowledgeBase(savedKB)
    }
  }, [])

  // Save selected knowledge base to localStorage when it changes
  const handleKnowledgeBaseChange = (value: string) => {
    console.log('Knowledge base changed from', selectedKnowledgeBase, 'to', value)
    setSelectedKnowledgeBase(value)
    localStorage.setItem('selectedKnowledgeBase', value)
    
    // Debug: Log the current file grouping
    console.log('Current filesByKnowledgeBase:', filesByKnowledgeBase)
    console.log('Files for selected KB:', filesByKnowledgeBase[value])
  }

  const loadExistingFiles = async () => {
    setIsLoading(true)
    try {
      const response = await fetch('/api/files')
      if (response.ok) {
        const files = await response.json()
        
        // Validate and sanitize file data before setting state
        const sanitizedFiles = files.map((file: any) => ({
          ...file,
          uploadTime: file.uploadTime ? new Date(file.uploadTime) : new Date(),
          processTime: file.processTime ? new Date(file.processTime) : undefined,
          // Ensure all required fields have fallback values
          id: file.id || `file-${Date.now()}-${Math.random()}`,
          name: file.name || 'Unknown file',
          size: file.size || 0,
          type: file.type || 'application/octet-stream',
          status: file.status || 'unknown',
          knowledgeBase: file.knowledgeBase || 'default',
          message: file.message || 'No message available'
        }))
        
        setFileStatuses(sanitizedFiles)
      } else {
        console.error('Failed to load files:', response.status, response.statusText)
      }
    } catch (error) {
      console.error('Failed to load files:', error)
      // Don't crash the component, just log the error
    } finally {
      setIsLoading(false)
    }
  }

  const loadKnowledgeBases = async () => {
    try {
      const response = await fetch('/api/knowledge-bases')
      if (response.ok) {
        const kbs = await response.json()
        setKnowledgeBases(kbs)
      }
    } catch (error) {
      console.error('Failed to load knowledge bases:', error)
    }
  }

  // Load existing files and set up periodic refresh
  useEffect(() => {
    loadExistingFiles()
    loadKnowledgeBases()
    
    // Set up periodic refresh every 30 seconds to keep file statuses in sync
    const refreshInterval = setInterval(() => {
      loadExistingFiles()
      loadKnowledgeBases()
    }, 30000)
    
    return () => clearInterval(refreshInterval)
  }, [])

  // Group files by knowledge base for better organization
  const filesByKnowledgeBase = fileStatuses.reduce((acc, file) => {
    if (!acc[file.knowledgeBase]) {
      acc[file.knowledgeBase] = []
    }
    acc[file.knowledgeBase].push(file)
    return acc
  }, {} as Record<string, FileStatus[]>)

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    if (acceptedFiles.length === 0) return

    const newFiles: FileStatus[] = acceptedFiles.map((file, index) => ({
      id: `${Date.now()}-${index}`,
      name: file.name,
      size: file.size,
      type: file.type,
      status: 'uploaded' as const,
      knowledgeBase: selectedKnowledgeBase,
      uploadTime: new Date(),
      message: 'File uploaded successfully'
    }))

    setFileStatuses(prev => [...prev, ...newFiles])

    // Upload files to Azure
    for (const file of acceptedFiles) {
      const formData = new FormData()
      formData.append('file', file)
      formData.append('knowledgeBase', selectedKnowledgeBase)

      try {
        const response = await fetch('/api/upload', {
          method: 'POST',
          body: formData
        })

        if (!response.ok) {
          throw new Error('Upload failed')
        }

        // Update file status to processing
        setFileStatuses(prev => 
          prev.map(f => 
            f.name === file.name 
              ? { ...f, status: 'processing' as const, message: 'Processing document...' }
              : f
          )
        )

        // Refresh file list to get updated status from storage containers
        setTimeout(() => {
          loadExistingFiles()
        }, 2000)

      } catch (error) {
        setFileStatuses(prev => 
          prev.map(f => 
            f.name === file.name 
              ? { ...f, status: 'error' as const, message: 'Upload failed' }
              : f
          )
        )
      }
    }
  }, [selectedKnowledgeBase, loadExistingFiles])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/pdf': ['.pdf'],
      'text/plain': ['.txt'],
      'text/markdown': ['.md'],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx']
    }
  })

  const createKnowledgeBase = async () => {
    if (!newKnowledgeBaseName.trim()) return

    setIsCreatingKB(true)
    
    try {
      const response = await fetch('/api/knowledge-bases', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ name: newKnowledgeBaseName.trim() })
      })

      if (response.ok) {
        const newKB = await response.json()
        setKnowledgeBases(prev => [...prev, newKB])
        setSelectedKnowledgeBase(newKB.id)
        setNewKnowledgeBaseName('')
        
        // Save to localStorage
        localStorage.setItem('selectedKnowledgeBase', newKB.id)
      } else {
        console.error('Failed to create knowledge base')
      }
    } catch (error) {
      console.error('Error creating knowledge base:', error)
    } finally {
      setIsCreatingKB(false)
    }
  }

  useEffect(() => {
    loadExistingFiles()
  }, [])

  const getStatusIcon = (status: FileStatus['status']) => {
    try {
      switch (status) {
        case 'uploaded':
          return <CheckCircle className="w-4 h-4 text-slate-400" />
        case 'processing':
          return <Clock className="w-4 h-4 text-slate-400" />
        case 'processed':
          return <CheckCircle className="w-4 h-4 text-slate-500" />
        case 'error':
          return <XCircle className="w-4 h-4 text-red-400" />
        default:
          return <FileText className="w-4 h-4 text-slate-400" />
      }
    } catch (error) {
      console.warn('Error getting status icon:', error)
      return <FileText className="w-4 h-4 text-slate-400" />
    }
  }

  const getStatusBadge = (status: FileStatus['status']) => {
    try {
      switch (status) {
        case 'uploaded':
          return <Badge variant="outline" className="text-xs bg-slate-50 border-slate-200 text-slate-500">Uploaded</Badge>
        case 'processing':
          return <Badge variant="outline" className="text-xs bg-slate-50 border-slate-200 text-slate-500">Processing</Badge>
        case 'processed':
          return <Badge variant="outline" className="text-xs bg-slate-50 border-slate-200 text-slate-600">Processed</Badge>
        case 'error':
          return <Badge variant="outline" className="text-xs bg-red-50 border-red-200 text-red-500">Error</Badge>
        default:
          return <Badge variant="outline" className="text-xs bg-slate-50 border-slate-200 text-slate-500">Unknown</Badge>
      }
    } catch (error) {
      console.warn('Error getting status badge:', error)
      return <Badge variant="outline" className="text-xs bg-slate-50 border-slate-200 text-slate-500">Unknown</Badge>
    }
  }

  const formatFileSize = (bytes: number) => {
    try {
      if (!bytes || bytes === 0 || isNaN(bytes)) return '0 Bytes'
      const k = 1024
      const sizes = ['Bytes', 'KB', 'MB', 'GB']
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
    } catch (error) {
      console.warn('Error formatting file size:', error)
      return 'Unknown size'
    }
  }

  const formatDate = (date: Date) => {
    try {
      // Validate the date before formatting
      if (!date || isNaN(date.getTime())) {
        return 'Invalid date'
      }
      
      return new Intl.DateTimeFormat('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      }).format(date)
    } catch (error) {
      console.warn('Error formatting date:', error)
      return 'Invalid date'
    }
  }

  return (
    <div className="space-y-4">
      {/* Compact Knowledge Base Management Bar */}
      <Card className="shadow-sm border-0 bg-white/50">
        <CardContent className="p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Label htmlFor="knowledge-base" className="text-sm font-normal text-slate-600">
                Knowledge Base:
              </Label>
              <Select value={selectedKnowledgeBase} onValueChange={handleKnowledgeBaseChange}>
                <SelectTrigger className="w-64 border-slate-200 bg-white">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {knowledgeBases.map((kb) => (
                    <SelectItem key={kb.id} value={kb.id}>
                      <div className="flex items-center justify-between w-full">
                        <span>{kb.name}</span>
                      </div>
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <span className="text-xs text-slate-400">
                {knowledgeBases.find(kb => kb.id === selectedKnowledgeBase)?.path}
              </span>
            </div>
            
            <div className="flex items-center gap-3">
              <Input
                placeholder="New knowledge base name"
                value={newKnowledgeBaseName}
                onChange={(e) => setNewKnowledgeBaseName(e.target.value)}
                className="w-48 border-slate-200 bg-white"
                onKeyPress={(e) => e.key === 'Enter' && createKnowledgeBase()}
              />
              <Button 
                onClick={createKnowledgeBase} 
                disabled={!newKnowledgeBaseName.trim() || isCreatingKB}
                size="sm"
                variant="outline"
                className={`flex items-center gap-2 px-3 py-2 ${
                  newKnowledgeBaseName.trim() && !isCreatingKB
                    ? 'border-green-500 text-green-600 hover:bg-green-500 hover:text-white hover:border-green-500'
                    : 'border-slate-200 bg-white text-slate-400 cursor-not-allowed'
                } transition-all duration-200`}
              >
                {isCreatingKB ? (
                  <RefreshCw className="w-4 h-4 animate-spin" />
                ) : (
                  <Plus className="w-4 h-4" />
                )}
                Create
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Hero Section - Document Organization */}
      <Card className="shadow-sm border-0 bg-white">
        <CardHeader className="pb-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <FolderOpen className="w-5 h-5 text-slate-400" />
              <div className="flex items-center gap-2">
                <span className="font-medium font-condensed text-base text-slate-600">
                  {knowledgeBases.find(kb => kb.id === selectedKnowledgeBase)?.name || 'Document Organization'}
                </span>
                <span className="font-sans text-xs text-slate-400 font-mono">
                  /{knowledgeBases.find(kb => kb.id === selectedKnowledgeBase)?.path || 'knowledge-base'}
                </span>
              </div>
            </div>
            <div className="flex items-center gap-3">
              {/* Prominent Upload Button */}
              <Button
                {...getRootProps()}
                size="default"
                className="bg-slate-900 hover:bg-slate-800 text-white border-0"
              >
                <input {...getInputProps()} />
                <div className="flex items-center gap-2 text-sm">
                  <Upload className="w-4 h-4" />
                  <span>Upload files</span>
                </div>
              </Button>
              
              <Button
                onClick={loadExistingFiles}
                disabled={isLoading}
                variant="outline"
                size="default"
                className="flex items-center gap-2 border-slate-200 bg-white text-slate-600 hover:bg-slate-50"
              >
                {isLoading ? (
                  <RefreshCw className="w-4 h-4 animate-spin" />
                ) : (
                  <RefreshCw className="w-4 h-4" />
                )}
                Refresh
              </Button>
            </div>
          </div>
        </CardHeader>
        
        <CardContent className="px-6 pb-6">
          {filesByKnowledgeBase[selectedKnowledgeBase] && filesByKnowledgeBase[selectedKnowledgeBase].length > 0 ? (
            <div className="space-y-3">
              {(() => {
                console.log(`Rendering files for KB: ${selectedKnowledgeBase}`)
                console.log(`Files to render:`, filesByKnowledgeBase[selectedKnowledgeBase])
                return filesByKnowledgeBase[selectedKnowledgeBase].map((fileStatus) => (
                  <Card key={fileStatus.id} className="border-0 shadow-sm bg-slate-50/50 hover:bg-slate-50 transition-colors">
                    <CardContent className="pt-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div className="flex-shrink-0">
                            {getStatusIcon(fileStatus.status)}
                          </div>
                          <div>
                            <div className="font-normal font-mono text-sm text-slate-700">
                              {fileStatus.name || 'Unknown file'}
                            </div>
                            <div className="text-xs text-slate-500 flex items-center gap-3 mt-1 leading-relaxed">
                              <span>{formatFileSize(fileStatus.size || 0)}</span>
                              <span>•</span>
                              <span className="font-mono">{fileStatus.type || 'unknown'}</span>
                              <span>•</span>
                              <span>{formatDate(fileStatus.uploadTime || new Date())}</span>
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center gap-3">
                          {getStatusBadge(fileStatus.status)}
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ))
              })()}
            </div>
          ) : (
            <div className="text-center py-10">
              <div className="text-4xl text-slate-300 mb-3">📁</div>
              <h3 className="text-base font-normal text-slate-500 mb-1 leading-relaxed">No documents yet</h3>
              <p className="text-sm text-slate-400 leading-relaxed">
                Upload your first document to get started with your knowledge base
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
} 