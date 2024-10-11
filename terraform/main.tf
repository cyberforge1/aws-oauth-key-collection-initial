# terraform/main.tf

provider "aws" {
  region = var.aws_region
}

# AWS Region Variable
variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "ap-southeast-2"
}

# Note: Since your Lambda function does not need VPC resources (unless specifically required), you can remove VPC-related resources if they are not necessary.

# If you still need the VPC setup, keep the following:

# Fetch available availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Generate unique IDs for VPC
resource "random_id" "vpc_id" {
  byte_length = 4
}

# Single VPC setup (Public Only)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc-${random_id.vpc_id.hex}"
  }
}

# Single Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

# Internet Gateway for Internet Access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Public Route Table
resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# VPC Endpoint for S3 (No cost)
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public_rt.id]
}

# Security Group for Lambda (if needed)
resource "aws_security_group" "lambda_sg" {
  name        = "lambda_sg"
  description = "Security group for Lambda"
  vpc_id      = aws_vpc.main.id

  # No ingress rules required unless Lambda is in the VPC

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Note: If your Lambda function does not need to be in a VPC, you can remove the VPC configuration and the `vpc_config` block in your Lambda function resource.
