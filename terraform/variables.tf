// Project and environment
variable "project_name" {
  description = "Project name for tagging and resource naming"
  type        = string
  default     = "cloud-devops-microservices"
}

variable "environment" {
  description = "Deployment environment tag (e.g., prod, staging, dev)"
  type        = string
  default     = "prod"
}

// Network configuration
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across"
  type        = number
  default     = 2
}

// RDS / Database variables (no hardcoded passwords)
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master DB username"
  type        = string
  default     = "dbadmin"
}

variable "db_password" {
  description = "Master DB password (sensitive). Do NOT hardcode in code; supply via secure means or tfvars." 
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Postgres engine version"
  type        = string
  default     = "15.3"
}

variable "backup_retention_period" {
  description = "Number of days to retain automated database backups"
  type        = number
  default     = 7
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the RDS instance (prevents accidental deletion)"
  type        = bool
  default     = true
}

// EC2 configuration
variable "my_ip_cidr" {
  description = "Your IP address in CIDR notation for SSH access (e.g., 203.0.113.25/32)"
  type        = string
  default     = "0.0.0.0/32" // Change this to your actual IP for security
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the API server"
  type        = string
  default     = "t3.small" // t3.small = ~$8/month; use t3.micro for testing
}
