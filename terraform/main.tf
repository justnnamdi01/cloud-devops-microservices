// VPC and Networking
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${var.environment}-vpc"
  }
}

// Create public and private subnets across availability zones
resource "aws_subnet" "public" {
  count = var.az_count
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.environment}-public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count = var.az_count
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + var.az_count)
  map_public_ip_on_launch = false
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.environment}-private-${count.index}"
  }
}

// Internet Gateway for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.environment}-igw"
  }
}

// Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  count = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

// NAT Gateway: one NAT in the first public subnet
resource "aws_eip" "nat_eip" {
  vpc = true
  tags = { Name = "${var.environment}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id
  tags = { Name = "${var.environment}-nat" }

  depends_on = [aws_internet_gateway.igw]
}

// Private route table pointing to NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "${var.environment}-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  count = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

// Security groups
resource "aws_security_group" "app_sg" {
  name   = "${var.environment}-app-sg"
  vpc_id = aws_vpc.main.id
  description = "Security group for application hosts; adjust rules as needed"

  // Allow outbound to anywhere (typical for app hosts)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-app-sg" }
}

resource "aws_security_group" "db_sg" {
  name   = "${var.environment}-db-sg"
  vpc_id = aws_vpc.main.id
  description = "Security group for RDS allowing only the app security group to connect"

  ingress {
    description = "Postgres from app SG"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  // Allow the DB to make outbound connections if needed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-db-sg" }
}

// RDS Subnet Group using private subnets
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags = { Name = "${var.environment}-rds-subnet-group" }
}

// RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-${var.environment}-postgres-db"
  engine = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  db_subnet_group_name = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  multi_az = true
  storage_encrypted = true
  publicly_accessible = false
  deletion_protection = var.enable_deletion_protection
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot = false
  final_snapshot_identifier = "${var.project_name}-${var.environment}-postgres-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name = "${var.environment}-postgres-db"
  }

  lifecycle {
    prevent_destroy = var.environment == "prod" ? true : false
  }
}
