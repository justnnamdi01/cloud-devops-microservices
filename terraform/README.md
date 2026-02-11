# Terraform Infrastructure for cloud-devops-microservices

Production-ready AWS infrastructure skeleton for hosting the FastAPI microservice with PostgreSQL RDS.

## Overview

This Terraform configuration provisions:
- **VPC** with public and private subnets across multiple availability zones
- **Internet Gateway** for public subnet ingress
- **NAT Gateway** for private subnet egress (single-AZ by default for cost)
- **Security Groups** for app and database tiers
- **RDS PostgreSQL** instance with Multi-AZ, encryption, and backups

## Cost Optimization: Single-AZ NAT Gateway

By default, this configuration uses a **single NAT Gateway** in the first public subnet. This approach:
- **Saves ~50%** on NAT Gateway costs (each NAT Gateway costs ~$32/month in most regions)
- Provides high availability for the database layer (Multi-AZ RDS)
- Accepts the trade-off: if the first AZ fails, private subnets lose outbound internet access until manually fixed

### Why This is Production-Ready for Most Teams

For **typical microservices**, the RDS failover is more critical than NAT redundancy. A brief loss of private subnet egress (package updates, external API calls) is less damaging than a database outage.

### Enabling Multi-AZ NAT (High Availability)

If your team requires NAT redundancy, you can modify `main.tf` to create one NAT Gateway per AZ:

```hcl
resource "aws_nat_gateway" "nat" {
  count         = var.az_count  # Create one per AZ
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  count  = var.az_count  # Create one per AZ
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index % var.az_count].id
  }
}
```

## Getting Started

### Prerequisites

- AWS account with appropriate IAM permissions
- Terraform >= 1.5.0
- AWS CLI configured

### Setup

1. **Initialize Terraform:**
   ```bash
   cd terraform
   terraform init
   ```

2. **Create a `terraform.tfvars` file** (do not commit):
   ```hcl
   db_password = "CHANGE_ME_TO_A_STRONG_PASSWORD"
   region      = "us-east-1"
   environment = "prod"
   ```

3. **Validate the configuration:**
   ```bash
   terraform validate
   terraform plan
   ```

4. **Apply the infrastructure:**
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

## Key Configuration

### Production Best Practices

- **RDS Multi-AZ:** Enabled by default for automatic failover
- **Storage Encryption:** Enabled for all RDS data
- **Deletion Protection:** Enabled by default (set `enable_deletion_protection = false` for dev)
- **Backup Retention:** 7 days by default (configurable via `backup_retention_period`)
- **Final Snapshot:** Enabled to prevent data loss; snapshots are preserved even after DB deletion
- **Environment-Based `prevent_destroy`:** Only prod environments have `prevent_destroy = true`
- **Default Tags:** All resources are tagged with `Project`, `Environment`, `ManagedBy`, and creation timestamp

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-east-1` | AWS region |
| `project_name` | `cloud-devops-microservices` | Project name for naming and tagging |
| `environment` | `prod` | Environment (prod/staging/dev) |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `az_count` | `2` | Number of availability zones |
| `db_name` | `appdb` | Database name |
| `db_username` | `dbadmin` | Master DB username |
| `db_password` | (required) | Master DB password (sensitive) |
| `db_instance_class` | `db.t3.medium` | RDS instance type |
| `db_allocated_storage` | `20` | Storage in GB |
| `backup_retention_period` | `7` | Backup retention days |
| `enable_deletion_protection` | `true` | Enable deletion protection |

### Outputs

After applying, key outputs include:
- `rds_connection_string` — Connection string (password-less, for reference)
- `db_endpoint` — RDS endpoint address
- `private_subnet_cidrs` — CIDR blocks for private subnets
- `vpc_id`, `public_subnets`, `private_subnets` — Network topology

## Next Steps

### Deploying the Application

1. **Retrieve RDS credentials and connection details:**
   ```bash
   terraform output rds_connection_string
   terraform output db_endpoint
   ```

2. **Set up ECS/EKS or EC2 instances** in the public/private subnets to run your Dockerized API.

3. **Update your `.env` or `docker-compose.yml`** to use the RDS endpoint and credentials.

### State Management

For production, move state to a remote backend (S3 + DynamoDB):

```hcl
// Add to provider.tf or create a backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "cloud-devops-microservices/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

Initialize with:
```bash
terraform init \
  -backend-config="bucket=my-terraform-state" \
  -backend-config="region=us-east-1"
```

## Security Considerations

- **Never commit `terraform.tfvars`** with sensitive data
- Use AWS Secrets Manager or Parameter Store for sensitive values in CI/CD
- Restrict IAM permissions to the minimum required
- Enable CloudTrail logging for infrastructure changes
- Regularly rotate RDS master password using AWS Secrets Manager Rotation

## Troubleshooting

### NAT Gateway Route Timeout

If private instances cannot reach the internet, check:
1. NAT Gateway is running in the correct AZ
2. Private route table has correct route to NAT
3. Instance security group allows outbound traffic

### RDS Connection Issues

- Verify security group allows inbound on port 5432 from app security group
- Check RDS is in the private subnets (use correct DB subnet group)
- Verify `DATABASE_URL` uses the correct RDS endpoint

## License

Same as parent project.
