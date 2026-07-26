#!/bin/bash
set -e

# 镜像版本/后缀配置
TAG_VERSION=${1:-"teledbx.2"}
REGISTRY="harbor.ctyuncdn.cn/esx-k8s"

# api代码生成
make gen_apis

# 编译代码
cd src
go mod tidy
go mod vendor

# 编译 amd64 架构二进制文件
echo "Building amd64 binaries..."
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -tags netgo -ldflags '-w -extldflags -static' -o harbor_core_amd64 core/main.go 
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -tags netgo -ldflags '-w -extldflags -static' -o harbor_jobservice_amd64 jobservice/main.go 

# 编译 arm64 架构二进制文件
echo "Building arm64 binaries..."
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -a -tags netgo -ldflags '-w -extldflags -static' -o harbor_core_arm64 core/main.go 
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -a -tags netgo -ldflags '-w -extldflags -static' -o harbor_jobservice_arm64 jobservice/main.go 

cd ..

# 使用 buildx 一键构建并推送多架构镜像（同时包含 linux/amd64 和 linux/arm64）
echo "Building multi-arch images with docker buildx for tag: v2.6.4-${TAG_VERSION}..."
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${REGISTRY}/harbor-core:v2.6.4-${TAG_VERSION} \
  -f Dockerfile.core . --push

docker buildx build --platform linux/amd64,linux/arm64 \
  -t ${REGISTRY}/harbor-jobservice:v2.6.4-${TAG_VERSION} \
  -f Dockerfile.jobservice . --push

echo "Build and push completed successfully!" 