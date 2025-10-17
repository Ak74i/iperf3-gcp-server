# Terraform configuration for iPerf3 high-speed test server
# Supports both Google Cloud Platform and Amazon Web Services

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Local variables for provider selection and common configuration
locals {
  is_gcp = var.cloud_provider == "gcp"
  is_aws = var.cloud_provider == "aws"
  
  # Common tags/labels for both providers
  common_labels = {
    project     = "iperf3-testing"
    environment = var.environment
    managed_by  = "terraform"
    repository  = "iperf3-multicloud-server"
  }

  # User data script path based on provider
  user_data_file = var.cloud_provider == "gcp" ? "scripts/gcp-startup.sh" : "scripts/aws-user-data.sh"
}

# ============================================================================
# GOOGLE CLOUD PLATFORM CONFIGURATION
# ============================================================================

# Configure the Google Cloud Provider
provider "google" {
  count = local.is_gcp ? 1 : 0
  
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# GCP: Create firewall rule for iPerf3
resource "google_compute_firewall" "iperf_firewall" {
  count = local.is_gcp ? 1 : 0
  
  name    = "${var.name_prefix}-iperf3-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = var.iperf_ports
  }

  allow {
    protocol = "udp"
    ports    = var.iperf_ports
  }

  # SSH access
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["iperf3-server"]
}

# GCP: Create compute instance
resource "google_compute_instance" "iperf_server_gcp" {
  count = local.is_gcp ? 1 : 0
  
  name         = var.server_name
  machine_type = var.gcp_machine_type
  zone         = var.gcp_zone

  tags = ["iperf3-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = var.gcp_ssh_key != "" ? "ubuntu:${var.gcp_ssh_key}" : ""
  }

  metadata_startup_script = templatefile("${path.module}/${local.user_data_file}", {
    server_name = var.server_name
  })

  labels = local.common_labels

  # Preemptible instance for cost savings
  scheduling {
    preemptible        = var.use_preemptible_spot
    on_host_maintenance = var.use_preemptible_spot ? "TERMINATE" : "MIGRATE"
    automatic_restart   = !var.use_preemptible_spot
  }
}

# ============================================================================
# AMAZON WEB SERVICES CONFIGURATION
# ============================================================================

# Configure the AWS Provider
provider "aws" {
  count = local.is_aws ? 1 : 0
  
  region = var.aws_region
  
  default_tags {
    tags = local.common_labels
  }
}

# AWS: Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  count = local.is_aws ? 1 : 0
  
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

# AWS: Get current caller identity
data "aws_caller_identity" "current" {
  count = local.is_aws ? 1 : 0
}

# AWS: Create VPC
resource "aws_vpc" "iperf_vpc" {
  count = local.is_aws && var.aws_create_vpc ? 1 : 0
  
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_labels, {
    Name = "${var.name_prefix}-vpc"
  })
}

# AWS: Create Internet Gateway
resource "aws_internet_gateway" "iperf_igw" {
  count = local.is_aws && var.aws_create_vpc ? 1 : 0
  
  vpc_id = aws_vpc.iperf_vpc[0].id

  tags = merge(local.common_labels, {
    Name = "${var.name_prefix}-igw"
  })
}

# AWS: Create public subnet
resource "aws_subnet" "iperf_public_subnet" {
  count = local.is_aws && var.aws_create_vpc ? 1 : 0
  
  vpc_id                  = aws_vpc.iperf_vpc[0].id
  cidr_block              = var.aws_public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_labels, {
    Name = "${var.name_prefix}-public-subnet"
    Type = "Public"
  })
}

# AWS: Create route table
resource "aws_route_table" "iperf_public_rt" {
  count = local.is_aws && var.aws_create_vpc ? 1 : 0
  
  vpc_id = aws_vpc.iperf_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.iperf_igw[0].id
  }

  tags = merge(local.common_labels, {
    Name = "${var.name_prefix}-public-rt"
  })
}

# AWS: Associate route table with subnet
resource "aws_route_table_association" "iperf_public_rta" {
  count = local.is_aws && var.aws_create_vpc ? 1 : 0
  
  subnet_id      = aws_subnet.iperf_public_subnet[0].id
  route_table_id = aws_route_table.iperf_public_rt[0].id
}

# AWS: Security group
resource "aws_security_group" "iperf_sg" {
  count = local.is_aws ? 1 : 0
  
  name        = "${var.name_prefix}-iperf3-sg"
  description = "Security group for iPerf3 test server"
  vpc_id      = var.aws_create_vpc ? aws_vpc.iperf_vpc[0].id : var.aws_existing_vpc_id

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

  # Health check port
  ingress {
    description = "Health Check"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_labels, {
    Name = "${var.name_prefix}-iperf3-sg"
  })
}

# AWS: Launch template
resource "aws_launch_template" "iperf_template" {
  count = local.is_aws ? 1 : 0
  
  name_prefix   = "${var.name_prefix}-iperf3-"
  image_id      = data.aws_ami.ubuntu[0].id
  instance_type = var.aws_instance_type
  key_name      = var.aws_key_name

  vpc_security_group_ids = [aws_security_group.iperf_sg[0].id]

  user_data = base64encode(templatefile("${path.module}/${local.user_data_file}", {
    server_name = var.server_name
  }))

  # Enable enhanced networking
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_labels, {
      Name = var.server_name
      Type = "iPerf3-Server"
    })
  }

  tags = merge(local.common_labels, {
    Name = "${var.name_prefix}-launch-template"
  })
}

# AWS: EC2 Instance (On-Demand)
resource "aws_instance" "iperf_server_aws" {
  count = local.is_aws && !var.use_preemptible_spot ? 1 : 0

  launch_template {
    id      = aws_launch_template.iperf_template[0].id
    version = "$Latest"
  }

  subnet_id = var.aws_create_vpc ? aws_subnet.iperf_public_subnet[0].id : var.aws_existing_subnet_id

  # Enable enhanced networking
  ena_support = true

  # Root block device
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.disk_size_gb
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(local.common_labels, {
    Name = var.server_name
    Type = "OnDemand"
  })
}

# AWS: Spot Instance Request
resource "aws_spot_instance_request" "iperf_spot" {
  count = local.is_aws && var.use_preemptible_spot ? 1 : 0

  spot_price                    = var.aws_spot_max_price
  instance_interruption_behavior = "terminate"
  wait_for_fulfillment          = true

  launch_template {
    id      = aws_launch_template.iperf_template[0].id
    version = "$Latest"
  }

  subnet_id = var.aws_create_vpc ? aws_subnet.iperf_public_subnet[0].id : var.aws_existing_subnet_id

  tags = merge(local.common_labels, {
    Name = "${var.server_name}-spot-request"
    Type = "SpotRequest"
  })
}

# AWS: Elastic IP (optional)
resource "aws_eip" "iperf_eip" {
  count = local.is_aws && var.use_elastic_ip ? 1 : 0

  domain = "vpc"
  instance = var.use_preemptible_spot ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server_aws[0].id

  depends_on = [
    var.use_preemptible_spot ? aws_spot_instance_request.iperf_spot[0] : aws_instance.iperf_server_aws[0],
    var.aws_create_vpc ? aws_internet_gateway.iperf_igw[0] : null
  ]

  tags = merge(local.common_labels, {
    Name = "${var.name_prefix}-eip"
  })
}

# ============================================================================
# MONITORING AND LOGGING (Provider-specific)
# ============================================================================

# AWS: CloudWatch Log Group
resource "aws_cloudwatch_log_group" "iperf_logs" {
  count = local.is_aws ? 1 : 0
  
  name              = "/aws/ec2/${var.server_name}"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_labels, {
    Name = "${var.name_prefix}-logs"
  })
}

# GCP: Logging (using default Cloud Logging)
# No additional resources needed for GCP logging as it's automatic

# ============================================================================
# CONDITIONAL OUTPUTS BASED ON PROVIDER
# ============================================================================

# Helper locals for outputs
locals {
  # Instance information
  instance_id = local.is_gcp ? google_compute_instance.iperf_server_gcp[0].instance_id : (
    var.use_preemptible_spot ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server_aws[0].id
  )
  
  # Public IP
  public_ip = local.is_gcp ? google_compute_instance.iperf_server_gcp[0].network_interface[0].access_config[0].nat_ip : (
    var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (
      var.use_preemptible_spot ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server_aws[0].public_ip
    )
  )
  
  # Private IP
  private_ip = local.is_gcp ? google_compute_instance.iperf_server_gcp[0].network_interface[0].network_ip : (
    var.use_preemptible_spot ? aws_spot_instance_request.iperf_spot[0].private_ip : aws_instance.iperf_server_aws[0].private_ip
  )
  
  # Zone/AZ
  zone = local.is_gcp ? google_compute_instance.iperf_server_gcp[0].zone : (
    var.use_preemptible_spot ? aws_spot_instance_request.iperf_spot[0].availability_zone : aws_instance.iperf_server_aws[0].availability_zone
  )
}
