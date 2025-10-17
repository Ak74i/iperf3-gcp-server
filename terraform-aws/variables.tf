# Terraform Variables for iPerf3 AWS Deployment

# General Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"  # London
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in the format like 'us-east-1' or 'eu-west-2'."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "test"
  
  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, staging, prod."
  }
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "iperf3"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.name_prefix))
    error_message = "Name prefix must start with a letter and contain only letters, numbers, and hyphens."
  }
}

variable "server_name" {
  description = "Name tag for the iPerf3 server instance"
  type        = string
  default     = "iPerf3-Test-Server"
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type optimized for network performance"
  type        = string
  default     = "c5n.xlarge"
  
  validation {
    condition = contains([
      "c5n.large", "c5n.xlarge", "c5n.2xlarge", "c5n.4xlarge",
      "m5n.large", "m5n.xlarge", "m5n.2xlarge", "m5n.4xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a high-performance networking instance type."
  }
}

variable "key_name" {
  description = "Name of the AWS key pair for EC2 access"
  type        = string
  
  validation {
    condition     = length(var.key_name) > 0
    error_message = "Key name cannot be empty."
  }
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "Root volume size must be between 8 and 100 GB."
  }
}

# Spot Instance Configuration
variable "use_spot_instance" {
  description = "Use spot instance instead of on-demand (60-70% cost savings)"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Maximum price for spot instance (per hour in USD)"
  type        = string
  default     = "0.065"  # About 30% of on-demand price for c5n.xlarge
  
  validation {
    condition     = can(tonumber(var.spot_max_price)) && tonumber(var.spot_max_price) > 0
    error_message = "Spot max price must be a positive number."
  }
}

# Network Configuration
variable "create_vpc" {
  description = "Create a new VPC for the deployment"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
  
  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "Public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "existing_vpc_id" {
  description = "ID of existing VPC (used when create_vpc = false)"
  type        = string
  default     = ""
}

variable "existing_subnet_id" {
  description = "ID of existing subnet (used when create_vpc = false)"
  type        = string
  default     = ""
}

variable "use_elastic_ip" {
  description = "Allocate and associate an Elastic IP address"
  type        = bool
  default     = false
}

# Security Configuration
variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Warning: This allows SSH from anywhere!
  
  validation {
    condition = alltrue([
      for cidr in var.ssh_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All SSH CIDR blocks must be valid IPv4 CIDR blocks."
  }
}

# Monitoring and Logging
variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring and alarms"
  type        = bool
  default     = true
}

variable "enable_auto_stop" {
  description = "Enable automatic instance stop when CPU is low (cost protection)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
  default     = ""
}

# Performance Testing Configuration
variable "iperf_ports" {
  description = "List of iPerf3 ports to configure"
  type        = list(number)
  default     = [5201, 5202, 5203, 5204, 5205]
  
  validation {
    condition = alltrue([
      for port in var.iperf_ports : port >= 1024 && port <= 65535
    ])
    error_message = "All iPerf3 ports must be between 1024 and 65535."
  }
}

# Cost Management
variable "max_monthly_cost_alert" {
  description = "Maximum monthly cost in USD before alerting (0 = disabled)"
  type        = number
  default     = 100
  
  validation {
    condition     = var.max_monthly_cost_alert >= 0
    error_message = "Maximum monthly cost alert must be non-negative."
  }
}

# Instance Performance Tuning
variable "enable_enhanced_networking" {
  description = "Enable enhanced networking (SR-IOV)"
  type        = bool
  default     = true
}

variable "enable_placement_group" {
  description = "Use placement group for consistent network performance"
  type        = bool
  default     = false
}

variable "placement_group_strategy" {
  description = "Placement group strategy (cluster, partition, spread)"
  type        = string
  default     = "cluster"
  
  validation {
    condition     = contains(["cluster", "partition", "spread"], var.placement_group_strategy)
    error_message = "Placement group strategy must be cluster, partition, or spread."
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Auto-scaling Configuration (Future Enhancement)
variable "enable_auto_scaling" {
  description = "Enable auto-scaling based on network utilization"
  type        = bool
  default     = false
}

variable "min_instances" {
  description = "Minimum number of instances in auto-scaling group"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_instances >= 0 && var.min_instances <= 10
    error_message = "Minimum instances must be between 0 and 10."
  }
}

variable "max_instances" {
  description = "Maximum number of instances in auto-scaling group"
  type        = number
  default     = 3
  
  validation {
    condition     = var.max_instances >= var.min_instances && var.max_instances <= 10
    error_message = "Maximum instances must be between min_instances and 10."
  }
}

# Backup Configuration
variable "enable_backup" {
  description = "Enable automated backups using AWS Backup"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "Backup retention days must be between 1 and 365."
  }
}

# Development and Testing
variable "allow_ssh_from_anywhere" {
  description = "Allow SSH access from any IP (WARNING: Security risk!)"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (additional cost)"
  type        = bool
  default     = false
}

variable "enable_instance_metadata_v2" {
  description = "Enforce Instance Metadata Service Version 2 (recommended for security)"
  type        = bool
  default     = true
}

# Data Sources and Computed Values
locals {
  # Common tags applied to all resources
  common_tags = merge(
    {
      Project      = "iPerf3-Testing"
      Environment  = var.environment
      ManagedBy    = "Terraform"
      Repository   = "iperf3-multicloud-server"
      CreatedDate  = timestamp()
    },
    var.additional_tags
  )
  
  # Instance cost estimation (approximation)
  estimated_hourly_cost = {
    "c5n.large"    = 0.108
    "c5n.xlarge"   = 0.216
    "c5n.2xlarge"  = 0.432
    "c5n.4xlarge"  = 0.864
    "m5n.large"    = 0.119
    "m5n.xlarge"   = 0.238
    "m5n.2xlarge"  = 0.476
    "m5n.4xlarge"  = 0.952
  }
  
  # Security group SSH CIDR - use restricted access if not allowing from anywhere
  ssh_cidrs = var.allow_ssh_from_anywhere ? ["0.0.0.0/0"] : var.ssh_cidr_blocks
  
  # Availability zone selection
  availability_zone = "${var.aws_region}a"
}

# Output estimated costs
output "estimated_monthly_cost_usd" {
  description = "Estimated monthly cost in USD (24/7 operation)"
  value = lookup(local.estimated_hourly_cost, var.instance_type, 0.20) * 24 * 30
}

output "estimated_hourly_cost_usd" {
  description = "Estimated hourly cost in USD"
  value = lookup(local.estimated_hourly_cost, var.instance_type, 0.20)
}
