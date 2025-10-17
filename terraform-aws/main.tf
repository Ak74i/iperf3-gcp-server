# Terraform configuration for iPerf3 high-speed test server on AWS
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "iPerf3-Testing"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "iperf3-multicloud-server"
    }
  }
}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create VPC
resource "aws_vpc" "iperf_vpc" {
  count = var.create_vpc ? 1 : 0
  
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "iperf_igw" {
  count = var.create_vpc ? 1 : 0
  
  vpc_id = aws_vpc.iperf_vpc[0].id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Create public subnet
resource "aws_subnet" "iperf_public_subnet" {
  count = var.create_vpc ? 1 : 0
  
  vpc_id                  = aws_vpc.iperf_vpc[0].id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-subnet"
    Type = "Public"
  }
}

# Create route table for public subnet
resource "aws_route_table" "iperf_public_rt" {
  count = var.create_vpc ? 1 : 0
  
  vpc_id = aws_vpc.iperf_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.iperf_igw[0].id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

# Associate route table with public subnet
resource "aws_route_table_association" "iperf_public_rta" {
  count = var.create_vpc ? 1 : 0
  
  subnet_id      = aws_subnet.iperf_public_subnet[0].id
  route_table_id = aws_route_table.iperf_public_rt[0].id
}

# Data source for existing VPC (if not creating new one)
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  
  id = var.existing_vpc_id
}

# Data source for existing subnet (if not creating new one)
data "aws_subnet" "existing" {
  count = var.create_vpc ? 0 : 1
  
  id = var.existing_subnet_id
}

# Security group for iPerf3 server
resource "aws_security_group" "iperf_sg" {
  name        = "${var.name_prefix}-iperf3-sg"
  description = "Security group for iPerf3 test server"
  vpc_id      = var.create_vpc ? aws_vpc.iperf_vpc[0].id : data.aws_vpc.existing[0].id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
  }

  # iPerf3 TCP ports
  ingress {
    description = "iPerf3 TCP"
    from_port   = 5201
    to_port     = 5205
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # iPerf3 UDP ports
  ingress {
    description = "iPerf3 UDP"
    from_port   = 5201
    to_port     = 5205
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-iperf3-sg"
  }
}

# User data script for server configuration
locals {
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_name = var.server_name
  }))
}

# Launch template for the iPerf3 server
resource "aws_launch_template" "iperf_template" {
  name_prefix   = "${var.name_prefix}-iperf3-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.iperf_sg.id]

  user_data = local.user_data

  # Enable enhanced networking
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Optimize for network performance
  placement {
    availability_zone = var.create_vpc ? aws_subnet.iperf_public_subnet[0].availability_zone : data.aws_subnet.existing[0].availability_zone
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.server_name
      Type = "iPerf3-Server"
    }
  }

  tags = {
    Name = "${var.name_prefix}-launch-template"
  }
}

# EC2 Instance (On-Demand)
resource "aws_instance" "iperf_server" {
  count = var.use_spot_instance ? 0 : 1

  launch_template {
    id      = aws_launch_template.iperf_template.id
    version = "$Latest"
  }

  subnet_id = var.create_vpc ? aws_subnet.iperf_public_subnet[0].id : var.existing_subnet_id

  # Enable enhanced networking (SR-IOV)
  ena_support = true

  # Instance store optimization
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = var.server_name
    Type = "OnDemand"
  }
}

# Spot Instance Request
resource "aws_spot_instance_request" "iperf_spot" {
  count = var.use_spot_instance ? 1 : 0

  spot_price                    = var.spot_max_price
  instance_interruption_behavior = "terminate"
  wait_for_fulfillment          = true

  launch_template {
    id      = aws_launch_template.iperf_template.id
    version = "$Latest"
  }

  subnet_id = var.create_vpc ? aws_subnet.iperf_public_subnet[0].id : var.existing_subnet_id

  tags = {
    Name = "${var.server_name}-spot-request"
    Type = "SpotRequest"
  }
}

# Elastic IP (optional)
resource "aws_eip" "iperf_eip" {
  count = var.use_elastic_ip ? 1 : 0

  domain = "vpc"
  instance = var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id

  depends_on = [
    var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0] : aws_instance.iperf_server[0],
    var.create_vpc ? aws_internet_gateway.iperf_igw[0] : null
  ]

  tags = {
    Name = "${var.name_prefix}-eip"
  }
}

# CloudWatch Log Group for monitoring
resource "aws_cloudwatch_log_group" "iperf_logs" {
  name              = "/aws/ec2/${var.server_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.name_prefix}-logs"
  }
}

# CloudWatch Alarm for high CPU (cost protection)
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.server_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    InstanceId = var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id
  }

  tags = {
    Name = "${var.name_prefix}-cpu-alarm"
  }
}

# CloudWatch Alarm for low CPU (auto-stop when idle)
resource "aws_cloudwatch_metric_alarm" "low_cpu_alarm" {
  count = var.enable_auto_stop ? 1 : 0

  alarm_name          = "${var.server_name}-low-cpu-autostop"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "6"  # 30 minutes of low CPU
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Auto-stop instance when CPU is low for 30 minutes"
  
  alarm_actions = [
    "arn:aws:automate:${var.aws_region}:ec2:stop"
  ]

  dimensions = {
    InstanceId = var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id
  }

  tags = {
    Name = "${var.name_prefix}-autostop-alarm"
  }
}
