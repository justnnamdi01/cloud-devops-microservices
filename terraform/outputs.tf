output "db_endpoint" {
  description = "RDS endpoint address"
  value       = aws_db_instance.postgres.endpoint
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.postgres.port
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.postgres.id
}

output "rds_connection_string" {
  description = "RDS connection string (without password for security)"
  value       = "postgresql://${var.db_username}@${aws_db_instance.postgres.endpoint}/${var.db_name}"
}

output "vpc_id" {
  description = "VPC id"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "app_security_group_id" {
  description = "App security group id"
  value       = aws_security_group.app_sg.id
}

output "db_security_group_id" {
  description = "DB security group id"
  value       = aws_security_group.db_sg.id
}

// EC2 outputs
output "ec2_public_ip" {
  description = "Public IP of the EC2 instance hosting the API"
  value       = aws_instance.api.public_ip
}

output "api_url" {
  description = "URL to access the API"
  value       = "http://${aws_instance.api.public_ip}:8000"
}

output "api_health_url" {
  description = "Health check endpoint"
  value       = "http://${aws_instance.api.public_ip}:8000/health"
}

output "api_docs_url" {
  description = "OpenAPI documentation endpoint"
  value       = "http://${aws_instance.api.public_ip}:8000/docs"
}

output "ec2_ssh_command" {
  description = "SSH command to connect to the EC2 instance"
  value       = "ssh -i your-key-pair.pem ec2-user@${aws_instance.api.public_ip}"
}
