provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

# Create a VPC
# tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "my-vpc"  # Name for the VPC
  }
}

# Create a public subnet in availability zone us-east-1a
# tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"  # First subnet in us-east-1a
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

# Create a second public subnet in the same availability zone (us-east-1a)
# tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"  # Second subnet in the same availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

# Create an Internet Gateway and attach it to the VPC
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main_vpc.id
}

# Create a Security Group that allows traffic from within the VPC and to/from the internet
# tfsec:ignore:aws-ec2-no-public-ingress-sgr
# tfsec:ignore:aws-ec2-add-description-to-security-group-rule
# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group" "allow_vpc_traffic" {
  name        = "allow_vpc_traffic"
  description = "Allow traffic within the VPC and to/from the internet"
  vpc_id      = aws_vpc.main_vpc.id

  # Allow inbound traffic from anywhere (public access)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP traffic from anywhere
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "ssh"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP traffic from anywhere
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # "-1" allows all protocols
    cidr_blocks = ["0.0.0.0/0"]  # Allow traffic from anywhere
  }

  # Allow all TCP traffic within the same security group
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "http"
    self            = true  # Allows traffic within the same SG
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "https"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTPS traffic from anywhere
  }

  # Allow inbound traffic from within the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow traffic from the entire VPC
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

# Create a route table to route traffic to the internet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

# Associate the route table with both public subnets
resource "aws_route_table_association" "public_route_table_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_route_table_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Store the VPC ID in SSM Parameter Store
resource "aws_ssm_parameter" "vpc_id_parameter" {
  name        = "/my-vpc/id"
  description = "VPC ID"
  type        = "String"
  value       = aws_vpc.main_vpc.id
}

# Store the Subnet IDs in SSM Parameter Store
resource "aws_ssm_parameter" "subnet_id_parameter_1" {
  name        = "/my-vpc/public-subnet-id-1"
  description = "Public Subnet ID - 1"
  type        = "String"
  value       = aws_subnet.public_subnet_1.id
}

resource "aws_ssm_parameter" "subnet_id_parameter_2" {
  name        = "/my-vpc/public-subnet-id-2"
  description = "Public Subnet ID - 2"
  type        = "String"
  value       = aws_subnet.public_subnet_2.id
}

# Store the Security Group ID in SSM Parameter Store
resource "aws_ssm_parameter" "security_group_id_parameter" {
  name        = "/my-vpc/security-group-id"
  description = "Security Group ID"
  type        = "String"
  value       = aws_security_group.allow_vpc_traffic.id
}
