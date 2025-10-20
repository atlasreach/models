#!/usr/bin/env node

/**
 * Sync GitHub Codespaces model dataset to AWS S3
 *
 * Usage: node sync-model-to-s3.js <model_name>
 * Example: node sync-model-to-s3.js blondie
 *
 * This script:
 * 1. Deletes all existing files in the S3 bucket under the model prefix
 * 2. Syncs local model files to S3, preserving folder structure
 * 3. Only includes .jpg files, caption .txt files, and meta.jsonl
 * 4. Organizes by model: s3://bucket/{model-name}/outputs/, {model-name}/captions/, etc.
 */

const { S3Client, PutObjectCommand, ListObjectsV2Command, DeleteObjectsCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const readdir = promisify(fs.readdir);
const stat = promisify(fs.stat);
const readFile = promisify(fs.readFile);

// Load environment variables
require('dotenv').config();

// Get model name from command line
const modelName = process.argv[2];

if (!modelName) {
  console.error('❌ Error: Model name is required');
  console.error('Usage: node sync-model-to-s3.js <model_name>');
  console.error('Example: node sync-model-to-s3.js blondie');
  process.exit(1);
}

// Configuration
const config = {
  modelName: modelName,
  bucket: process.env.AWS_S3_BUCKET || 'modelcrew',
  region: process.env.AWS_REGION || 'us-east-2',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
};

// Validate configuration
if (!config.accessKeyId || !config.secretAccessKey) {
  console.error('❌ Error: AWS credentials not found in environment variables');
  console.error('   Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY');
  process.exit(1);
}

// Initialize S3 client
const s3Client = new S3Client({
  region: config.region,
  credentials: {
    accessKeyId: config.accessKeyId,
    secretAccessKey: config.secretAccessKey,
  },
});

// File paths to sync
const sourcePaths = {
  images: path.join('/workspaces/models', modelName, 'outputs/faceswapped'),
  captions: path.join('/workspaces/models/dataset', modelName, 'captions'),
  meta: path.join('/workspaces/models/dataset', modelName, 'meta/meta.jsonl'),
};

/**
 * Get all files in a directory recursively
 */
async function getFiles(dir, filter = null) {
  const files = [];

  try {
    const items = await readdir(dir);

    for (const item of items) {
      const fullPath = path.join(dir, item);
      const stats = await stat(fullPath);

      if (stats.isDirectory()) {
        files.push(...await getFiles(fullPath, filter));
      } else {
        if (!filter || filter(fullPath)) {
          files.push(fullPath);
        }
      }
    }
  } catch (error) {
    // Directory doesn't exist, skip silently
    if (error.code !== 'ENOENT') {
      console.error(`❌ Error reading directory ${dir}:`, error.message);
    }
  }

  return files;
}

/**
 * Delete all objects under the model prefix in S3
 */
async function deleteExistingFiles() {
  console.log(`\n🗑️  Deleting existing files for model '${config.modelName}' in S3...`);

  try {
    let continuationToken;
    let totalDeleted = 0;

    do {
      // List objects with model prefix
      const listCommand = new ListObjectsV2Command({
        Bucket: config.bucket,
        Prefix: `${config.modelName}/`,
        ContinuationToken: continuationToken,
      });

      const listResponse = await s3Client.send(listCommand);

      if (listResponse.Contents && listResponse.Contents.length > 0) {
        // Delete objects in batches of 1000 (S3 limit)
        const objectsToDelete = listResponse.Contents.map(obj => ({ Key: obj.Key }));

        const deleteCommand = new DeleteObjectsCommand({
          Bucket: config.bucket,
          Delete: {
            Objects: objectsToDelete,
            Quiet: false,
          },
        });

        const deleteResponse = await s3Client.send(deleteCommand);
        const deletedCount = deleteResponse.Deleted?.length || 0;
        totalDeleted += deletedCount;

        console.log(`   Deleted ${deletedCount} files...`);
      }

      continuationToken = listResponse.NextContinuationToken;
    } while (continuationToken);

    console.log(`✅ Deleted ${totalDeleted} existing files from S3\n`);
  } catch (error) {
    console.error('❌ Error deleting existing files:', error.message);
    throw error;
  }
}

/**
 * Upload a file to S3
 */
async function uploadFile(localPath, s3Key) {
  try {
    const fileContent = await readFile(localPath);
    const contentType = getContentType(localPath);

    const command = new PutObjectCommand({
      Bucket: config.bucket,
      Key: s3Key,
      Body: fileContent,
      ContentType: contentType,
    });

    await s3Client.send(command);
    return true;
  } catch (error) {
    console.error(`   ❌ Failed to upload ${s3Key}:`, error.message);
    return false;
  }
}

/**
 * Get content type based on file extension
 */
function getContentType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const contentTypes = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.txt': 'text/plain',
    '.jsonl': 'application/jsonl',
  };
  return contentTypes[ext] || 'application/octet-stream';
}

/**
 * Main sync function
 */
async function sync() {
  console.log('🚀 Starting S3 sync...');
  console.log(`   Model: ${config.modelName}`);
  console.log(`   Bucket: ${config.bucket}`);
  console.log(`   Region: ${config.region}\n`);

  // Step 1: Delete existing files for this model
  await deleteExistingFiles();

  // Step 2: Collect files to upload
  console.log('📂 Collecting files to upload...\n');

  const filesToUpload = [];

  // Collect .jpg images from {model}/outputs/faceswapped/
  if (fs.existsSync(sourcePaths.images)) {
    const imageFiles = await getFiles(sourcePaths.images, (file) => file.endsWith('.jpg'));
    for (const file of imageFiles) {
      const relativePath = path.relative(sourcePaths.images, file);
      const s3Key = `${config.modelName}/outputs/faceswapped/${relativePath}`;
      filesToUpload.push({ localPath: file, s3Key });
    }
    console.log(`   Found ${imageFiles.length} .jpg images`);
  } else {
    console.log(`   ⚠️  Images directory not found: ${sourcePaths.images}`);
  }

  // Collect caption .txt files from dataset/{model}/captions/
  if (fs.existsSync(sourcePaths.captions)) {
    const captionFiles = await getFiles(sourcePaths.captions, (file) => file.endsWith('.txt'));
    for (const file of captionFiles) {
      const fileName = path.basename(file);
      const s3Key = `${config.modelName}/captions/${fileName}`;
      filesToUpload.push({ localPath: file, s3Key });
    }
    console.log(`   Found ${captionFiles.length} caption .txt files`);
  } else {
    console.log(`   ⚠️  Captions directory not found: ${sourcePaths.captions}`);
  }

  // Collect meta.jsonl
  if (fs.existsSync(sourcePaths.meta)) {
    const s3Key = `${config.modelName}/meta/meta.jsonl`;
    filesToUpload.push({ localPath: sourcePaths.meta, s3Key });
    console.log(`   Found meta.jsonl`);
  } else {
    console.log(`   ⚠️  Meta file not found: ${sourcePaths.meta}`);
  }

  if (filesToUpload.length === 0) {
    console.log('\n⚠️  No files to upload');
    return;
  }

  // Step 3: Upload files
  console.log(`\n📤 Uploading ${filesToUpload.length} files to S3...\n`);

  let uploadedCount = 0;
  let failedCount = 0;

  for (let i = 0; i < filesToUpload.length; i++) {
    const { localPath, s3Key } = filesToUpload[i];
    const fileName = path.basename(localPath);

    process.stdout.write(`   [${i + 1}/${filesToUpload.length}] Uploading ${fileName}...`);

    const success = await uploadFile(localPath, s3Key);

    if (success) {
      uploadedCount++;
      process.stdout.write(' ✅\n');
    } else {
      failedCount++;
      process.stdout.write(' ❌\n');
    }
  }

  // Summary
  console.log('\n' + '='.repeat(50));
  console.log('📊 Sync Complete!');
  console.log('='.repeat(50));
  console.log(`Model: ${config.modelName}`);
  console.log(`✅ Successfully uploaded: ${uploadedCount} files`);
  if (failedCount > 0) {
    console.log(`❌ Failed uploads: ${failedCount} files`);
  }
  console.log(`📍 S3 Location: s3://${config.bucket}/${config.modelName}/`);
  console.log('='.repeat(50) + '\n');
}

// Run the sync
sync().catch((error) => {
  console.error('\n❌ Sync failed:', error.message);
  process.exit(1);
});
