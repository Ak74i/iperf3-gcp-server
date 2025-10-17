# Terraform Variables for Multi-Cloud iPerf3 Deployment
# Supports both Google Cloud Platform and Amazon Web Services

# ============================================================================
# PROVIDER SELECTION (REQUIRED)
# ============================================================================

variable "cloud_provider" {
  description = "Cloud provider to use (gcp or aws)"
  type        = string
  
  validation {
    condition     = contains(["gcp", "aws"], var.cloud_provider)
    error_message = "Cloud provider must be either 'gcp' or 'aws'."
  }
}

# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================

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

# ============================================================================
# INSTANCE CONFIGURATION
# ============================================================================

variable "disk_size_gb" {
  description = "Size of the root disk in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.disk_size_gb >= 10 && var.disk_size_gb <= 100
    error_message = "Disk size must be between 10 and 100 GB."
  }
}

variable "use_preemptible_spot" {
  description = "Use preemptible (GCP) or spot (AWS) instances for cost savings"
  type        = bool
  default     = false
}

variable "use_elastic_ip" {
  description = "Allocate static IP address (AWS only)"
  type        = bool
  default     = false
}

# ============================================================================
# GOOGLE CLOUD PLATFORM CONFIGURATION
# ============================================================================

variable "gcp_project_id" {
  description = "GCP Project ID (required when cloud_provider = 'gcp')"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "europe-west2"  # London
  
  validation {
    condition = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.gcp_region))
    error_message = "GCP region must be in the format like 'us-central1' or 'europe-west2'."
  }
}

variable "gcp_zone" {
  description = "GCP zone for deployment"
  type        = string
  default     = "europe-west2-a"
  
  validation {
    condition = can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.gcp_zone))
    error_message = "GCP zone must be in the format like 'us-central1-a' or 'europe-west2-a'."
  }
}

variable "gcp_machine_type" {
  description = "GCP machine type optimized for network performance"
  type        = string
  default     = "n1-standard-4"
  
  validation {
    condition = contains([
      "n1-standard-2", "n1-standard-4", "n1-standard-8",
      "n2-standard-2", "n2-standard-4", "n2-standard-8",
      "c2-standard-4", "c2-standard-8", "c2-standard-16"
    ], var.gcp_machine_type)
    error_message = "Machine type must be a high-performance networking instance type."
  }
}

variable "gcp_ssh_key" {
  description = "SSH public key for GCP instance access"
  type        = string
  default     = ""
}

# ============================================================================
# AMAZON WEB SERVICES CONFIGURATION
# ============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-west-2"  # London
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in the format like 'us-east-1' or 'eu-west-2'."
  }
}

variable "aws_instance_type" {
  description = "AWS instance type optimized for network performance"
  type        = string
  default     = "c5n.xlarge"
  
  validation {
    condition = contains([
      "c5n.large", "c5n.xlarge", "c5n.2xlarge", "c5n.4xlarge",
      "m5n.large", "m5n.xlarge", "m5n.2xlarge", "m5n.4xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge", "c5.4xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge", "m5.4xlarge"
    ], var.aws_instance_type)
    error_message = "Instance type must be a high-performance networking instance type."
  }
}

variable "aws_key_name" {
  description = "Name of the AWS key pair for EC2 access (required when cloud_provider = 'aws')"
  type        = string
  default     = ""
}

variable "aws_spot_max_price" {
  description = "Maximum price for AWS spot instance (per hour in USD)"
  type        = string
  default     = "0.065"
  
  validation {
    condition     = can(tonumber(var.aws_spot_max_price)) && tonumber(var.aws_spot_max_price) > 0
    error_message = "Spot max price must be a positive number."
  }
}

# ============================================================================
# AWS NETWORK CONFIGURATION
# ============================================================================

variable "aws_create_vpc" {
  description = "Create a new VPC for AWS deployment"
  type        = bool
  default     = true
}

variable "aws_vpc_cidr" {
  description = "CIDR block for the AWS VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.aws_vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "aws_public_subnet_cidr" {
  description = "CIDR block for the AWS public subnet"
  type        = string
  default     = "10.0.1.0/24"
  
  validation {
    condition     = can(cidrhost(var.aws_public_subnet_cidr, 0))
    error_message = "Public subnet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "aws_existing_vpc_id" {
  description = "ID of existing AWS VPC (used when aws_create_vpc = false)"
  type        = string
  default     = ""
}

variable "aws_existing_subnet_id" {
  description = "ID of existing AWS subnet (used when aws_create_vpc = false)"
  type        = string
  default     = ""
}

# ============================================================================
# SECURITY CONFIGURATION
# ============================================================================

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

variable "allow_ssh_from_anywhere" {
  description = "Allow SSH access from any IP (WARNING: Security risk!)"
  type        = bool
  default     = true
}

# ============================================================================
# IPERF3 CONFIGURATION
# ============================================================================

variable "iperf_ports" {
  description = "List of iPerf3 ports to configure"
  type        = list(string)
  default     = ["5201", "5202", "5203", "5204", "5205"]
  
  validation {
    condition = alltrue([
      for port in var.iperf_ports : can(tonumber(port)) && tonumber(port) >= 1024 && tonumber(port) <= 65535
    ])
    error_message = "All iPerf3 ports must be numbers between 1024 and 65535."
  }
}

# ============================================================================
# MONITORING AND LOGGING
# ============================================================================

variable "enable_monitoring" {
  description = "Enable cloud monitoring and logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid retention period."
  }
}

variable "enable_auto_stop" {
  description = "Enable automatic instance stop when CPU is low (cost protection)"
  type        = bool
  default     = false
}

# ============================================================================
# TAGS AND LABELS
# ============================================================================

variable "additional_tags" {
  description = "Additional tags/labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# COST MANAGEMENT
# ============================================================================

variable "max_monthly_cost_alert" {
  description = "Maximum monthly cost in USD before alerting (0 = disabled)"
  type        = number
  default     = 100
  
  validation {
    condition     = var.max_monthly_cost_alert >= 0
    error_message = "Maximum monthly cost alert must be non-negative."
  }
}

# ============================================================================
# PERFORMANCE TUNING
# ============================================================================

variable "enable_enhanced_networking" {
  description = "Enable enhanced networking features"
  type        = bool
  default     = true
}

variable "enable_placement_group" {
  description = "Use placement group for consistent network performance (AWS only)"
  type        = bool
  default     = false
}

# ============================================================================
# VALIDATION AND COMPUTED VALUES
# ============================================================================

locals {
  # Validate provider-specific required variables
  gcp_required_vars_check = var.cloud_provider == "gcp" ? (
    var.gcp_project_id != "" ? true : tobool("GCP project ID is required when cloud_provider = 'gcp'")
  ) : true
  
  aws_required_vars_check = var.cloud_provider == "aws" ? (
    var.aws_key_name != "" ? true : tobool("AWS key name is required when cloud_provider = 'aws'")
  ) : true
  
  # Ensure zone matches region for GCP
  gcp_zone_region_check = var.cloud_provider == "gcp" ? (
    startswith(var.gcp_zone, var.gcp_region) ? true : tobool("GCP zone must be within the specified region")
  ) : true
  
  # Cost estimation per provider
  estimated_hourly_cost_gcp = {
    "n1-standard-2" = 0.095
    "n1-standard-4" = 0.190
    "n1-standard-8" = 0.380
    "n2-standard-2" = 0.097
    "n2-standard-4" = 0.194
    "n2-standard-8" = 0.388
    "c2-standard-4" = 0.199
    "c2-standard-8" = 0.398
  }
  
  estimated_hourly_cost_aws = {
    "c5n.large"    = 0.108
    "c5n.xlarge"   = 0.216
    "c5n.2xlarge"  = 0.432
    "c5n.4xlarge"  = 0.864
    "m5n.large"    = 0.119
    "m5n.xlarge"   = 0.238
    "m5n.2xlarge"  = 0.476
    "m5n.4xlarge"  = 0.952
  }
  
  # Get estimated cost based on provider and instance type
  estimated_cost = var.cloud_provider == "gcp" ? lookup(local.estimated_hourly_cost_gcp, var.gcp_machine_type, 0.15) : lookup(local.estimated_hourly_cost_aws, var.aws_instance_type, 0.20)
  
  # Network performance expectations
  network_performance_gcp = {
    "n1-standard-2" = "Up to 10 Gbps"
    "n1-standard-4" = "Up to 10 Gbps"
    "n1-standard-8" = "Up to 16 Gbps"
    "n2-standard-2" = "Up to 10 Gbps"
    "n2-standard-4" = "Up to 10 Gbps"
    "n2-standard-8" = "Up to 16 Gbps"
    "c2-standard-4" = "Up to 10 Gbps"
    "c2-standard-8" = "Up to 16 Gbps"
  }
  
  network_performance_aws = {
    "c5n.large"    = "Up to 10 Gbps"
    "c5n.xlarge"   = "Up to 25 Gbps"
    "c5n.2xlarge"  = "Up to 25 Gbps"
    "c5n.4xlarge"  = "Up to 50 Gbps"
    "m5n.large"    = "Up to 10 Gbps"
    "m5n.xlarge"   = "Up to 25 Gbps"
    "m5n.2xlarge"  = "Up to 25 Gbps"
    "m5n.4xlarge"  = "Up to 50 Gbps"
  }
  
  expected_network_performance = var.cloud_provider == "gcp" ? lookup(local.network_performance_gcp, var.gcp_machine_type, "Up to 10 Gbps") : lookup(local.network_performance_aws, var.aws_instance_type, "Up to 25 Gbps")
  
  # Security CIDR optimization
  ssh_cidrs = var.allow_ssh_from_anywhere ? ["0.0.0.0/0"] : var.ssh_cidr_blocks
}

# ============================================================================
# PROVIDER-SPECIFIC FEATURE FLAGS
# ============================================================================

variable "gcp_enable_ip_forwarding" {
  description = "Enable IP forwarding on GCP instance"
  type        = bool
  default     = false
}

variable "aws_enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (additional cost)"
  type        = bool
  default     = false
}

variable "aws_enable_instance_metadata_v2" {
  description = "Enforce Instance Metadata Service Version 2 (recommended for security)"
  type        = bool
  default     = true
}

# ============================================================================
# BACKUP AND DISASTER RECOVERY
# ============================================================================

variable "enable_backup" {
  description = "Enable automated backups"
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

# ============================================================================
# DEVELOPMENT AND TESTING OPTIONS
# ============================================================================

variable "debug_mode" {
  description = "Enable debug mode with additional logging"
  type        = bool
  default     = false
}

variable "test_mode" {
  description = "Enable test mode with minimal resources"
  type        = bool
  default     = false
}
