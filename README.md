# cloud-devops-microservices

This project is a minimal FastAPI microservice scaffold with SQLAlchemy and Alembic for migrations.

## Database and Migrations

The application reads the database URL from the `DATABASE_URL` environment variable. Example:

```powershell
$env:DATABASE_URL = "postgresql+psycopg2://postgres:postgres@localhost:5432/cloud_devops"
```

Alembic is configured to use the same `DATABASE_URL` via the application's `config` module.

### Initialize and run migrations

Create an automatic migration (based on `models`):

```powershell
# From project root
alembic revision --autogenerate -m "init"
```

Apply migrations:

```powershell
alembic upgrade head
```

Notes:
- The project intentionally removed `Base.metadata.create_all(...)` from application startup so that database schema is managed by Alembic migrations.
- For development you can keep using `alembic revision --autogenerate` to generate new revisions based on SQLAlchemy models, then run `alembic upgrade head` to apply them.

## Running locally (dev)

Activate the virtual environment, set `DATABASE_URL`, and run uvicorn:

```powershell
.\.venv\Scripts\Activate.ps1
$env:DATABASE_URL = "postgresql+psycopg2://postgres:postgres@localhost:5432/cloud_devops"
uvicorn cloud_devops_microservices.app:app --reload
```

## Alembic notes

- Alembic's `env.py` imports the package and `models.Base.metadata` as `target_metadata`, and it overrides the config's `sqlalchemy.url` using the app `get_settings()` value so migrations always use the same database URL.
- Migrations live in `alembic/versions/`.

## Run locally with Docker

### 1) Configure environment
```bash
cp .env.example .env
```

### 2) Quick commands using Makefile

Use the included `Makefile` to manage the local Docker environment:

```bash
# Start the app and DB (build images if needed)
make up

# Follow logs
make logs

# Stop and remove containers
make down

# Remove volumes and orphans (reset state)
make reset

# Run migrations inside the running api container
make migrate

# Open a shell in the api container
make shell
```

Open the OpenAPI docs at: http://localhost:8000/docs

Health endpoint: GET http://localhost:8000/health

## CI/CD: GitHub Actions and ECR

The project includes a GitHub Actions workflow (`.github/workflows/ecr-push.yml`) that automatically builds and pushes the Docker image to Amazon ECR on every push to `main`.

### Setup: GitHub OIDC + AWS Role

This workflow uses GitHub OpenID Connect (OIDC) for secure, keyless AWS authentication—no long-lived AWS credentials stored in GitHub.

#### 1. Create an AWS IAM Role for GitHub

Use the Terraform or AWS CLI to create a role. Example (via AWS CLI):

```bash
# Set your GitHub repo and AWS account
export GITHUB_REPO="your-org/cloud-devops-microservices"
export AWS_ACCOUNT_ID="123456789012"

# Create trust policy JSON
cat > trust-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name github-actions-ecr-push \
  --assume-role-policy-document file://trust-policy.json
```

#### 2. Attach ECR Push Policy to the Role

```bash
# Create an inline policy for ECR access
cat > ecr-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:CreateRepository",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:*:${AWS_ACCOUNT_ID}:repository/cloud-devops-microservices-api"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name github-actions-ecr-push \
  --policy-name ecr-push \
  --policy-document file://ecr-policy.json
```

#### 3. Create ECR Repository (if not already created)

```bash
aws ecr create-repository \
  --repository-name cloud-devops-microservices-api \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true \
  --image-tag-mutability MUTABLE
```

#### 4. Configure GitHub Repository Variables

In your GitHub repo settings (`Settings > Secrets and variables > Actions`), add these **Variables** (not secrets):

| Variable | Value |
|----------|-------|
| `AWS_ACCOUNT_ID` | Your AWS account ID (e.g., `123456789012`) |
| `AWS_REGION` | AWS region (e.g., `us-east-1`) |
| `OIDC_ROLE_NAME` | IAM role name (e.g., `github-actions-ecr-push`) |

> **Note:** These are `Variables`, not `Secrets`. They are not sensitive and do not need to be encrypted.

### Workflow Behavior

When you push to `main`, the workflow:
1. Checks out the code
2. Assumes the GitHub OIDC role using OIDC token (no AWS credentials needed)
3. Logs in to ECR
4. Builds the Docker image from `docker/Dockerfile`
5. Tags the image with `latest` and the git commit SHA
6. Pushes both tags to ECR

### Running the Image Locally

After the workflow pushes an image, you can pull and run it locally:

```bash
# Log in to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Pull the latest image
docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/cloud-devops-microservices-api:latest

# Run the image with environment variables
docker run -e DATABASE_URL=postgresql://... -p 8000:8000 \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/cloud-devops-microservices-api:latest
```

### Troubleshooting

**Workflow fails with "Role not found":**
- Verify `OIDC_ROLE_NAME` is correct
- Check OIDC provider is configured (`token.actions.githubusercontent.com`)

**"not authorized" on ECR push:**
- Confirm IAM role has `ecr:PutImage` and `ecr:CompleteLayerUpload` permissions
- Verify ECR repository exists in the specified region

**Image pull fails locally:**
- Ensure you've run `aws ecr get-login-password` before `docker pull`
- Check region matches where the repository was created

## Production Deployment: EC2 (Option A)

This project includes Terraform configuration for running the API on an EC2 instance—a cost-effective alternative to EKS for small to medium teams.

### Architecture

- **EC2 instance** (t3.small ~$8/month) in a public subnet
- **RDS PostgreSQL** in private subnets (Multi-AZ, encrypted)
- **IAM role** for EC2 to pull Docker images from ECR
- **Security groups** for SSH and API access
- **Systemd service** to manage the Docker container and auto-restart on reboot

### Deployment Steps

#### 1. Update Terraform Variables

Create `terraform/terraform.tfvars`:

```hcl
db_password = "YOUR_SECURE_PASSWORD"
region      = "us-east-1"
environment = "prod"
my_ip_cidr  = "203.0.113.25/32"  # Replace with YOUR IP for SSH access
```

To find your IP:
```bash
curl https://checkip.amazonaws.com
```

Then add `/32` to make it a CIDR (e.g., `203.0.113.25/32`).

#### 2. Ensure ECR Repository Exists

The GitHub Actions workflow creates the ECR repository, OR create it manually:

```bash
aws ecr create-repository \
  --repository-name cloud-devops-microservices-api \
  --region us-east-1
```

#### 3. Push a Docker Image to ECR

Either trigger the GitHub Actions workflow by pushing to `main`, or build locally:

```bash
# Build locally
docker build -f docker/Dockerfile -t cloud-devops-microservices-api:latest .

# Tag for ECR
docker tag cloud-devops-microservices-api:latest \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/cloud-devops-microservices-api:latest

# Log in to ECR and push
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/cloud-devops-microservices-api:latest
```

#### 4. Apply Terraform to Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

Terraform will output:
- `ec2_public_ip` — Public IP of your EC2 instance
- `api_url` — `http://<public_ip>:8000`
- `api_health_url` — `http://<public_ip>:8000/health`
- `api_docs_url` — `http://<public_ip>:8000/docs`
- `ec2_ssh_command` — SSH command to connect

#### 5. Access the API

After Terraform completes (~5 minutes for RDS to be ready), verify the API:

```bash
# Health check
curl http://<EC2_PUBLIC_IP>:8000/health

# OpenAPI docs
open http://<EC2_PUBLIC_IP>:8000/docs
```

### Monitoring and Updates

#### View Logs from the EC2 Instance

```bash
# SSH into the instance
ssh -i your-key-pair.pem ec2-user@<EC2_PUBLIC_IP>

# View the systemd service logs
sudo journalctl -u api -f

# View Docker logs
sudo docker logs -f cloud-devops-api

# View user data script output
sudo cat /var/log/user-data.log
```

#### Update the Deployment

**Option 1: Pull latest image and restart (manual)**

```bash
ssh -i your-key-pair.pem ec2-user@<EC2_PUBLIC_IP>

# Pull the latest image
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/cloud-devops-microservices-api:latest

# Restart the service
sudo systemctl restart api
```

**Option 2: Automated redeploy script (save to EC2)**

Create a `redeploy.sh` on the EC2 instance:

```bash
#!/bin/bash
set -euo pipefail

echo "Pulling latest image..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/cloud-devops-microservices-api:latest

echo "Restarting service..."
sudo systemctl restart api

echo "Waiting for API to be ready..."
sleep 5
curl http://localhost:8000/health && echo "API is ready!"
```

Then run:
```bash
bash redeploy.sh
```

Or trigger via a GitHub webhook if you set up a simple endpoint on the EC2 instance.

#### Auto-Recovery

The Terraform configuration:
- Creates a systemd service (`/etc/systemd/system/api.service`) with `Restart=always`
- Ensures the Docker container restarts on failure or EC2 reboot
- Enables EC2 monitoring

### Cost Estimation

| Component | Monthly Cost |
|-----------|--------------|
| EC2 t3.small | ~$8 |
| RDS Multi-AZ (db.t3.medium, 20GB) | ~$100 |
| NAT Gateway | ~$32 (single-AZ) |
| ECR storage (small image ~100MB) | <$1 |
| **Total** | **~$141/month** |

Compare to EKS (~$73 + compute + NAT), EC2 is significantly cheaper for small teams.

### Troubleshooting

**"Connection refused" when accessing API:**
- EC2 security group may not allow inbound on port 8000
- Check: `aws ec2 describe-security-groups --group-ids <sg_id>`
- Or modify the security group in the EC2 console

**"API takes a long time to start":**
- Docker image is being pulled and started for the first time
- Check logs: `sudo journalctl -u api -f`
- RDS may still be initializing; wait a few more minutes

**"ECR login fails":**
- IAM role may not have `ecr:GetAuthorizationToken` permission
- Verify policy in `terraform/ec2.tf`

**"Database connection error":**
- RDS security group must allow inbound from EC2 security group on port 5432
- Terraform handles this automatically; verify SG rules if issues persist

### Next Steps

- **Add CloudFront CDN** in front of the API (terraform/cloudfront.tf)
- **Set up Route53** DNS (terraform/route53.tf)
- **Enable auto-scaling** with ASG for multiple EC2 instances
- **Use Systems Manager Session Manager** instead of SSH for more secure access
