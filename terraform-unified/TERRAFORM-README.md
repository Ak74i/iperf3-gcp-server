# Multi-Cloud Terraform Deployment for iPerf3 Server

This directory contains a **unified Terraform configuration** that supports deploying iPerf3 high-speed test servers on both **Google Cloud Platform** and **Amazon Web Services** using a single codebase.

## 🚀 Quick Start

### Prerequisites
- [Terraform](https://terraform.io/downloads) installed (>= 1.0)
- Cloud provider CLI configured:
  - **AWS**: [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws configure`)
  - **GCP**: [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured (`gcloud auth login`)

### 1. Choose Your Cloud Provider
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit and set your cloud provider
vim terraform.tfvars
```

**Set the cloud provider (REQUIRED):**
```hcl
# For Amazon Web Services
cloud_provider = "aws"
aws_region = "eu-west-2"
aws_key_name = "my-aws-key"

# OR for Google Cloud Platform  
cloud_provider = "gcp"
gcp_project_id = "my-gcp-project"
gcp_region = "europe-west2"
gcp_zone = "europe-west2-a"
```

### 2. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Review deployment plan
terraform plan

# Deploy infrastructure
terraform apply
```

### 3. Test Your Server
```bash
# Get deployment summary
terraform output deployment_summary

# Test performance
iperf3 -c $(terraform output -raw public_ip) -p 5201 -R -t 30 -P 4
```

## 📁 Directory Structure

```
terraform/
├── main.tf                      # Core multi-cloud configuration
├── variables.tf                 # Input variables for both providers
├── outputs.tf                   # Output values supporting both providers
├── terraform.tfvars.example     # Configuration examples
├── scripts/
│   ├── gcp-startup.sh          # GCP instance startup script
│   └── aws-user-data.sh        # AWS instance user data script
└── README.md                   # This file
```

## ⚙️ Configuration Examples

### Amazon Web Services
```hcl
# Basic AWS configuration
cloud_provider = "aws"
aws_region = "eu-west-2"
aws_instance_type = "c5n.xlarge"
aws_key_name = "my-key-pair"
```

### Google Cloud Platform  
```hcl
# Basic GCP configuration
cloud_provider = "gcp"
gcp_project_id = "my-project-123456"
gcp_region = "europe-west2"
gcp_zone = "europe-west2-a"
gcp_machine_type = "n1-standard-4"
```

### Cost Optimization (Both Providers)
```hcl
# Enable spot/preemptible instances for 60-70% savings
use_preemptible_spot = true

# AWS specific
aws_spot_max_price = "0.065"

# Auto-stop when idle
enable_auto_stop = true
```

## 🌍 Multi-Cloud Comparison

| Feature                 | Google Cloud Platform     | Amazon Web Services |
|-------------------------|---------------------------|---------------------|
| **Variable Prefix**     | `gcp_*`                   | `aws_*`             |
| **Default Instance**    | n1-standard-4             | c5n.xlarge          |
| **Network Performance** | Up to 10 Gbps             | Up to 25 Gbps       |
| **Estimated Cost/Hour** | ~$0.19                    | ~$0.22              |
| **Spot Savings**        | ~70% (preemptible)        | ~60-70% (spot)      |
| **Best For**            | Balanced cost/performance | Maximum performance |

## 🔧 Key Features

### **Multi-Cloud Support**
- Single Terraform configuration for both providers
- Provider-specific optimizations
- Unified variable interface
- Consistent outputs regardless of provider

### **High Performance**
- **AWS**: Enhanced networking (SR-IOV), up to 25 Gbps instances
- **GCP**: High-performance networking, up to 10 Gbps instances
- Network optimizations (BBR congestion control)
- 5 parallel iPerf3 instances (ports 5201-5205)

### **Cost Management**
- Spot/preemptible instance support
- Auto-stop when idle (configurable)
- Cost estimation in outputs
- Hourly/monthly cost projections

### **Professional Features**
- Infrastructure as Code with validation
- Cloud-native monitoring integration
- Health check endpoints
- Comprehensive management scripts

## 🧪 Testing Commands

### Basic Performance Tests
```bash
# Get server IP
SERVER_IP=$(terraform output -raw public_ip)

# Download test (recommended)
iperf3 -c $SERVER_IP -p 5201 -R -t 30 -P 4

# Upload test
iperf3 -c $SERVER_IP -p 5201 -t 30 -P 4

# UDP test (high bandwidth)
iperf3 -c $SERVER_IP -p 5201 -u -b 3G -R -t 30
```

### Multi-Port Testing
```bash
# Test all 5 server instances
terraform output -raw multi_port_test_script > test-all-ports.sh
chmod +x test-all-ports.sh
./test-all-ports.sh
```

### Server Management
```bash
# SSH to server (provider-aware)
$(terraform output -raw ssh_command)

# Check server status
$(terraform output -raw ssh_command) 'iperf3-status'

# Stop instance (save money!)
$(terraform output -raw cloud_management_commands | jq -r '.stop_instance')
```

## 💰 Cost Management

### Get Cost Estimates
```bash
# View cost information
terraform output cost_estimation

# Cost optimization tips
terraform output cost_optimization_tips
```

### Example Costs (USD, On-Demand)

**Google Cloud Platform:**
| Instance Type | Hourly | Daily (8h)   | Monthly (24/7) |
|---------------|--------|--------------|----------------|
| n1-standard-2 | $0.095 | $0.76        | $68            |
| n1-standard-4 | $0.190 | $1.52        | $137           |

**Amazon Web Services:**
| Instance Type | Hourly | Daily (8h) | Monthly (24/7) |
|---------------|--------|------------|----------------|
| c5n.large     | $0.108 | $0.86      | $78            |
| c5n.xlarge    | $0.216 | $1.73      | $156           |

**Spot/Preemptible Savings:** 60-70% cost reduction

## 🔍 Troubleshooting

### Common Issues

**1. Provider Authentication**
```bash
# AWS
aws sts get-caller-identity

# GCP  
gcloud auth list
```

**2. Missing Required Variables**
```bash
# Check which variables are required
terraform validate
```

**3. Instance Access Issues**
```bash
# Get troubleshooting info
terraform output troubleshooting_info

# Check cloud console
terraform output cloud_console_links
```

### Provider-Specific Troubleshooting

**AWS Issues:**
- Verify key pair exists in target region
- Check security group allows SSH from your IP
- Ensure instance type is available in region

**GCP Issues:**
- Verify project ID is correct
- Check SSH keys are properly configured
- Ensure APIs are enabled (Compute Engine API)

## 📊 Advanced Configuration

### Network Performance Tuning
```hcl
# Enhanced networking (AWS)
enable_enhanced_networking = true

# Placement groups for multiple instances
enable_placement_group = true

# Custom iPerf3 ports
iperf_ports = ["5201", "5202", "5203", "5204", "5205"]
```

### Security Configuration
```hcl
# Restrict SSH access
allow_ssh_from_anywhere = false
ssh_cidr_blocks = ["203.0.113.0/24"]  # Your office network

# AWS security enhancements
aws_enable_instance_metadata_v2 = true
```

### Monitoring and Logging
```hcl
# Enable monitoring
enable_monitoring = true
log_retention_days = 30

# Auto-stop when idle
enable_auto_stop = true
```

## 🔗 Useful Outputs

After deployment, these outputs are available:

| Output                 | Description                     |
|------------------------|---------------------------------|
| `public_ip`            | Server public IP address        |
| `ssh_command`          | Provider-specific SSH command   |
| `iperf3_test_commands` | Ready-to-use test commands      |
| `deployment_summary`   | Complete deployment information |
| `cost_estimation`      | Cost breakdown and estimates    |
| `cloud_console_links`  | Direct links to cloud consoles  |

## 🚀 Quick Commands Reference

```bash
# Deploy on AWS
echo 'cloud_provider = "aws"' > terraform.tfvars
echo 'aws_region = "us-east-1"' >> terraform.tfvars
echo 'aws_key_name = "my-key"' >> terraform.tfvars
terraform init && terraform apply

# Deploy on GCP
echo 'cloud_provider = "gcp"' > terraform.tfvars
echo 'gcp_project_id = "my-project"' >> terraform.tfvars
echo 'gcp_region = "us-central1"' >> terraform.tfvars
echo 'gcp_zone = "us-central1-a"' >> terraform.tfvars
terraform init && terraform apply

# Test performance
iperf3 -c $(terraform output -raw public_ip) -p 5201 -R -t 30 -P 4

# Stop instance
$(terraform output -raw cloud_management_commands | jq -r '.stop_instance')

# Destroy everything
terraform destroy
```

## 📚 Additional Resources

- **Cloud-Specific Guides**: 
  - [AWS deployment guide](../README-AWS.md)
  - [GCP deployment guide](../README-GCP.md)
- **Main Documentation**: [Project README](../README.md)
- **Performance Testing**: [Testing guidelines](../docs/)

## 🤝 Support

- **Terraform Issues**: [Terraform Documentation](https://terraform.io/docs)
- **AWS Issues**: [AWS Documentation](https://docs.aws.amazon.com/)
- **GCP Issues**: [Google Cloud Documentation](https://cloud.google.com/docs)
- **iPerf3 Questions**: [Project Issues](https://github.com/YOUR_USERNAME/iperf3-multicloud-server/issues)

---

**Multi-cloud made simple!** 🌍☁️
