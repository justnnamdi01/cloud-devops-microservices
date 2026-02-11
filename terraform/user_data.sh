#!/bin/bash
set -euo pipefail

# Log everything for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user_data script..."

# Update system packages
yum update -y

# Install Docker
yum install -y docker

# Add ec2-user to docker group for sudoless docker commands
usermod -aG docker ec2-user

# Start Docker service
systemctl start docker
systemctl enable docker

# Wait for Docker to be ready
sleep 5

# Install AWS CLI (comes pre-installed on AL2023, but ensure it's there)
yum install -y aws-cli

echo "Docker and AWS CLI installed successfully"

# Log in to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com

# Create app directory
mkdir -p /opt/api
cd /opt/api

# Pull the latest image
echo "Pulling Docker image from ECR..."
docker pull ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repository}:latest

# Create .env file for the container
cat > /opt/api/.env << 'ENVEOF'
# Database configuration
POSTGRES_USER=${db_username}
POSTGRES_PASSWORD=${db_password}
POSTGRES_DB=${db_name}
DB_HOST=${db_host}
DB_PORT=${db_port}
DATABASE_URL=postgresql+psycopg2://${db_username}:${db_password}@${db_host}:${db_port}/${db_name}
ENVEOF

# Secure the .env file (credentials should not be world-readable)
chown root:root /opt/api/.env
chmod 600 /opt/api/.env

echo ".env file created and secured (600 permissions)"

# Create a systemd service to manage the Docker container
cat > /etc/systemd/system/api.service << 'SVCEOF'
[Unit]
Description=Cloud DevOps Microservices API
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/api
EnvironmentFile=/opt/api/.env

# Remove any existing container before starting
ExecStartPre=/usr/bin/docker rm -f cloud-devops-api || true

# Pull the latest image before starting (ensures fresh deployment)
ExecStartPre=/usr/bin/docker pull ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repository}:latest

# Run the container (note: no --rm so we can inspect logs after exit)
ExecStart=/usr/bin/docker run \
  --name cloud-devops-api \
  -p 8000:8000 \
  --env-file /opt/api/.env \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repository}:latest

# Stop the container gracefully
ExecStop=/usr/bin/docker stop cloud-devops-api

# Restart policy: always restart on failure or system reboot
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

# Reload systemd and enable the service
systemctl daemon-reload
systemctl enable api
systemctl start api

echo "API service started successfully"
echo "Waiting for API to be ready..."
sleep 10

# Check if API is responding using Python urllib (no curl dependency)
for i in {1..30}; do
  if python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=2)" 2>/dev/null; then
    echo "API is ready!"
    break
  else
    echo "Waiting for API... (attempt $i/30)"
    sleep 2
  fi
done

echo "User data script completed successfully"
