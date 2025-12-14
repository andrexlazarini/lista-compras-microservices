#!/usr/bin/env sh
set -e

echo "Creating bucket shopping-images (LocalStack)..."
awslocal s3 mb s3://shopping-images || true
echo "Buckets:"
awslocal s3 ls
