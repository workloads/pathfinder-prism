# Web upload app

A modern Next.js application for uploading documents to Azure Blob Storage as part of the Azure Nomad Workshop. This application serves as the frontend interface that users interact with to upload their documents into your AI pipeline.

## Features

The app provides a modern UI built with Next.js 14, TypeScript, and Tailwind CSS. Users get an intuitive drag and drop interface for file uploads, real-time status tracking for upload progress, direct integration with Azure Blob Storage, support for PDF, TXT, MD, and DOCX files, and built-in health checks for monitoring. It delivers a clean, professional file upload interface with modern design principles.

## Development and deployment

You'll need Node.js 18 or higher, npm or yarn for package management, and Docker if you want to build containerized images. The app is designed to work seamlessly with the rest of your workshop infrastructure.

Start by installing dependencies, then run the development server for local testing. When you're ready for production, build the app and start the production server.

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

Build the Docker image using the provided build script or manually with Docker commands. This creates the container image that gets deployed to your Nomad cluster.

```bash
# Build the Docker image
./build.sh

# Or manually
docker build -t web-upload-app:latest .
```

## Configuration and architecture

The application requires several environment variables to function properly. You'll need Azure storage credentials for blob access, container configuration for organizing uploads, and the public URL where users can access your app.

- `AZURE_STORAGE_ACCOUNT`: Azure Storage account name
- `AZURE_STORAGE_ACCESS_KEY`: Azure Storage access key
- `UPLOAD_CONTAINER`: Container name for uploads (default: "uploads")
- `NEXT_PUBLIC_APP_URL`: Public URL of the application

The app exposes two main API endpoints. The health check endpoint tells you if the service is running properly, while the upload endpoint handles the actual file uploads to Azure Blob Storage.

- `GET /api/health`: Health check endpoint
- `POST /api/upload`: File upload endpoint

The application is structured as a modern Next.js app with API routes and React components. The main upload logic lives in the API routes, while the user interface is built with React components and styled with Tailwind CSS.

```
app/
├── api/
│   ├── health/
│   │   └── route.ts          # Health check API
│   └── upload/
│       └── route.ts          # File upload API
├── components/
│   └── FileUpload.tsx        # Main upload component
├── globals.css               # Global styles
├── layout.tsx                # Root layout
└── page.tsx                  # Main page
```

## Integration and deployment

This app is designed to work seamlessly with the Azure Nomad Workshop pipeline. Users upload documents through the web interface, which stores files in the `uploads` container. The file processor monitors this container and processes documents automatically, then adds the processed results to OpenWebUI's knowledge base for AI interaction.

The application is deployed as a Nomad job using the Docker image you build locally. See the main workshop documentation for complete deployment instructions and integration with your Nomad cluster. 