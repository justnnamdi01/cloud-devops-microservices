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

# Install Docker Compose plugin
curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

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
ExecStart=/usr/bin/docker run --rm \
  --name cloud-devops-api \
  -p 8000:8000 \
  --env-file /opt/api/.env \
  ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repository}:latest
ExecStop=/usr/bin/docker stop cloud-devops-api
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

# Check if API is responding
for i in {1..30}; do
  if curl -f http://localhost:8000/health 2>/dev/null; then
    echo "API is ready!"
    break
  else
    echo "Waiting for API... (attempt $i/30)"
    sleep 2
  fi
done

echo "User data script completed successfully"
