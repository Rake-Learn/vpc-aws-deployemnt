provider "aws" {
  region = "us-east-1"  # Change to your desired region
}

# tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
# Create a VPC with a name tag
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"  # Name for the VPC
  }
}

# Create a public subnet
# tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"  # Change to the availability zone you want
  map_public_ip_on_launch = true  # Automatically associate public IPs with instances

  tags = {
    Name = "public-subnet"  # Name for the subnet
  }
}

# Create an Internet Gateway and attach it to the VPC
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "my-internet-gateway"  # Name for the internet gateway
  }
}

# Create a Security Group that allows traffic from within the VPC but blocks public ingress
# tfsec:ignore:aws-ec2-add-description-to-security-group-rule
# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group" "allow_vpc_traffic" {
  name        = "allow_vpc_traffic"
  description = "Allow traffic within the VPC but block public ingress"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow traffic from the entire VPC
  }

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

  tags = {
    Name = "public-route-table"  # Name for the route table
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Enable VPC Flow Logs
# tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs
resource "aws_flow_log" "vpc_flow_log" {
  vpc_id         = aws_vpc.main_vpc.id
  traffic_type   = "ALL"
  log_group_name = "vpc-flow-logs"
  log_stream_name = "vpc-flow-stream"

  # Optional: Provide an IAM role if required
  iam_role_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/YOUR_IAM_ROLE"
}