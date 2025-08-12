'use client'

import React, { useState, useCallback } from 'react'
import { useDropzone } from 'react-dropzone'

interface UploadStatus {
  file: File
  status: 'uploading' | 'success' | 'error'
  progress: number
  message?: string
}

export default function FileUpload() {
  const [uploadStatuses, setUploadStatuses] = useState<UploadStatus[]>([])

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    const newStatuses: UploadStatus[] = acceptedFiles.map(file => ({
      file,
      status: 'uploading',
      progress: 0
    }))
    
    setUploadStatuses(prev => [...prev, ...newStatuses])

    for (let i = 0; i < acceptedFiles.length; i++) {
      const file = acceptedFiles[i]
      const statusIndex = uploadStatuses.length + i
      
      try {
        const formData = new FormData()
        formData.append('file', file)
        
        const response = await fetch('/api/upload', {
          method: 'POST',
          body: formData,
        })
        
        if (response.ok) {
          setUploadStatuses(prev => 
            prev.map((status, index) => 
              index === statusIndex 
                ? { ...status, status: 'success', progress: 100, message: 'Upload successful!' }
                : status
            )
          )
        } else {
          throw new Error('Upload failed')
        }
      } catch (error) {
        setUploadStatuses(prev => 
          prev.map((status, index) => 
            index === statusIndex 
              ? { ...status, status: 'error', progress: 0, message: 'Upload failed' }
              : status
          )
        )
      }
    }
  }, [uploadStatuses.length])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/pdf': ['.pdf'],
      'text/plain': ['.txt'],
      'text/markdown': ['.md'],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx']
    }
  })

  return (
    <div className="space-y-6">
      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors ${
          isDragActive 
            ? 'border-blue-400 bg-blue-50' 
            : 'border-gray-300 hover:border-gray-400'
        }`}
      >
        <input {...getInputProps()} />
        <div className="space-y-4">
          <div className="text-6xl text-gray-400">📄</div>
          <div>
            <p className="text-lg font-medium text-gray-900">
              {isDragActive ? 'Drop files here' : 'Drag & drop files here'}
            </p>
            <p className="text-sm text-gray-500 mt-1">
              or click to select files
            </p>
          </div>
          <p className="text-xs text-gray-400">
            Supports PDF, TXT, MD, DOCX files
          </p>
        </div>
      </div>

      {uploadStatuses.length > 0 && (
        <div className="space-y-3">
          <h3 className="font-semibold text-gray-900">Upload Status</h3>
          {uploadStatuses.map((status, index) => (
            <div key={index} className="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg">
              <div className="flex-1">
                <p className="font-medium text-gray-900">{status.file.name}</p>
                {status.message && (
                  <p className={`text-sm ${
                    status.status === 'success' ? 'text-green-600' : 
                    status.status === 'error' ? 'text-red-600' : 'text-gray-600'
                  }`}>
                    {status.message}
                  </p>
                )}
              </div>
              <div className="flex items-center space-x-2">
                {status.status === 'uploading' && (
                  <div className="w-4 h-4 border-2 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
                )}
                {status.status === 'success' && (
                  <div className="w-4 h-4 bg-green-500 rounded-full flex items-center justify-center">
                    <span className="text-white text-xs">✓</span>
                  </div>
                )}
                {status.status === 'error' && (
                  <div className="w-4 h-4 bg-red-500 rounded-full flex items-center justify-center">
                    <span className="text-white text-xs">✗</span>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
} 