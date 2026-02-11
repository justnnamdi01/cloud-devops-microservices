// EC2 instance for hosting the FastAPI application
// This is a more cost-effective alternative to EKS for small teams

// Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

// Security group for EC2 instance
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.environment}-ec2-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for EC2 hosting the API"

  // SSH access from specified CIDR
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  // HTTP for demo or load balancer health checks
  ingress {
    description = "HTTP from anywhere (optional, consider restricting)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // HTTPS from anywhere
  ingress {
    description = "HTTPS from anywhere (optional)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // API port (8000) for direct access or Nginx proxy
  ingress {
    description = "API port from anywhere"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-ec2-sg"
  }
}

// IAM role for EC2 instance (ECR pull + CloudWatch)
resource "aws_iam_role" "ec2_role" {
  name_prefix = "${var.environment}-ec2-"
  description = "Role for EC2 instance to pull from ECR and access CloudWatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

// Policy for ECR pull
resource "aws_iam_role_policy" "ec2_ecr_policy" {
  name_prefix = "ecr-pull-"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })
}

// Policy for CloudWatch Logs (optional but recommended)
resource "aws_iam_role_policy" "ec2_cloudwatch_policy" {
  name_prefix = "cloudwatch-logs-"
  role        = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.region}:*:*"
      }
    ]
  })
}

// Instance profile to attach role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${var.environment}-ec2-"
  role        = aws_iam_role.ec2_role.name
}

// User data script to configure and start the application
locals {
  user_data_script = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_account_id = data.aws_caller_identity.current.account_id
    aws_region     = var.region
    ecr_repository = "cloud-devops-microservices-api"
    rds_endpoint   = aws_db_instance.postgres.endpoint
    db_name        = var.db_name
    db_username    = var.db_username
    db_password    = var.db_password
    db_host        = aws_db_instance.postgres.address
    db_port        = aws_db_instance.postgres.port
  }))
}

// Fetch AWS account ID for ECR URI
data "aws_caller_identity" "current" {}

// EC2 instance
resource "aws_instance" "api" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = local.user_data_script

  associate_public_ip_address = true

  tags = {
    Name = "${var.environment}-api-instance"
  }

  monitoring = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = true
  }
}
