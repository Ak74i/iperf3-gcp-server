# Terraform AWS Deployment for iPerf3 Server

This directory contains Terraform configuration for deploying an iPerf3 high-speed test server on Amazon Web Services.

## 🚀 Quick Start

### Prerequisites
- [Terraform](https://terraform.io/downloads) installed (>= 1.0)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured
- AWS EC2 key pair created in target region

### 1. Configure Variables
```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings
vim terraform.tfvars
```

**Minimum required configuration:**
```hcl
aws_region = "eu-west-2"      # Your preferred region
key_name   = "my-key-pair"    # Your EC2 key pair name
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
After deployment, Terraform will output connection details:
```bash
# Test download performance
iperf3 -c YOUR_SERVER_IP -p 5201 -R -t 30 -P 4
```

## 📁 Files Overview

| File                       | Purpose                        |
|----------------------------|--------------------------------|
| `main.tf`                  | Core infrastructure resources  |
| `variables.tf`             | Input variables and validation |
| `outputs.tf`               | Output values after deployment |
| `user-data.sh`             | Server configuration script    |
| `terraform.tfvars.example` | Configuration examples         |

## ⚙️ Configuration Options

### Instance Types (Recommended for 3+ Gbps, prices are in USD)

| Instance Type | vCPUs | RAM    | Network       | Cost/Hour* |
|---------------|-------|--------|---------------|------------|
| `c5n.large`   | 2     | 5.25GB | Up to 10 Gbps | ~$0.11     |
| `c5n.xlarge`  | 4     | 10.5GB | Up to 25 Gbps | ~$0.22     |
| `c5n.2xlarge` | 8     | 21GB   | Up to 25 Gbps | ~$0.43     |

*Pricing for US-East-1 region

### Cost Optimization

**Use Spot Instances (60-70% savings):**
```hcl
use_spot_instance = true
spot_max_price    = "0.065"  # ~30% of on-demand price
```

**Enable Auto-Stop:**
```hcl
enable_auto_stop = true  # Stop when CPU < 5% for 30 minutes
```

### Network Configuration

**Create New VPC (Default):**
```hcl
create_vpc = true
vpc_cidr = "10.0.0.0/16"
```

**Use Existing VPC:**
```hcl
create_vpc = false
existing_vpc_id = "vpc-xxxxxxxxx"
existing_subnet_id = "subnet-xxxxxxxxx"
```

### Security

**Restrict SSH Access:**
```hcl
ssh_cidr_blocks = ["YOUR_IP/32"]  # Replace with your public IP
```

**Enable Enhanced Features:**
```hcl
use_elastic_ip = true              # Static IP address
enable_monitoring = true           # CloudWatch monitoring
enable_enhanced_networking = true  # SR-IOV support
```

## 📊 Example Configurations

### 1. Basic Testing (Low Cost)
```hcl
aws_region = "us-east-1"
key_name   = "my-key"
instance_type = "c5n.large"
use_spot_instance = true
spot_max_price = "0.035"
```

### 2. High Performance
```hcl
aws_region = "eu-west-2"
key_name   = "my-key"
instance_type = "c5n.2xlarge"
use_elastic_ip = true
enable_monitoring = true
```

### 3. Production Deployment
```hcl
aws_region = "us-west-2"
key_name   = "prod-key"
instance_type = "c5n.xlarge"
use_elastic_ip = true
enable_monitoring = true
enable_auto_stop = true
ssh_cidr_blocks = ["10.0.0.0/8"]  # Corporate network only
```

## 🔧 Management Commands

### After Deployment
```bash
# Get server details
terraform output

# SSH to server
terraform output -raw ssh_command

# Stop instance (save money!)
terraform output -raw aws_cli_commands | jq -r '.stop_instance'

# Destroy everything
terraform destroy
```

### Server Management
```bash
# SSH to server
ssh ubuntu@$(terraform output -raw public_ip)

# Check server status
ssh ubuntu@$(terraform output -raw public_ip) 'iperf3-status'

# View logs
ssh ubuntu@$(terraform output -raw public_ip) 'iperf3-logs'
```

## 🧪 Testing Performance

### Basic Tests
```bash
SERVER_IP=$(terraform output -raw public_ip)

# Download test (3+ Gbps capable)
iperf3 -c $SERVER_IP -p 5201 -R -t 30 -P 4

# Upload test
iperf3 -c $SERVER_IP -p 5201 -t 30 -P 4

# UDP test
iperf3 -c $SERVER_IP -p 5201 -u -b 3G -R -t 30
```

### Multi-Port Testing
```bash
# Test all 5 server instances
for port in {5201..5205}; do
    iperf3 -c $SERVER_IP -p $port -t 30 &
done
wait
```

## 💰 Cost Management

### Monitor Costs
```bash
# Get current instance cost estimate
terraform output estimated_hourly_cost_usd
terraform output estimated_monthly_cost_usd
```

### Stop/Start Instance
```bash
# Stop (data preserved, no compute charges)
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id) --region $(terraform output -raw aws_region)

# Start
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id) --region $(terraform output -raw aws_region)
```

## 🔍 Troubleshooting

### Common Issues

**1. Key pair not found:**
```bash
# List available key pairs
aws ec2 describe-key-pairs --region YOUR_REGION

# Create new key pair
aws ec2 create-key-pair --key-name my-iperf3-key --region YOUR_REGION
```

**2. Permission denied (SSH):**
```bash
# Check security group allows your IP
terraform output security_group_id

# Update SSH CIDR blocks in terraform.tfvars
ssh_cidr_blocks = ["$(curl -s https://ipinfo.io/ip)/32"]
terraform apply
```

**3. Instance not accessible:**
```bash
# Check instance status
aws ec2 describe-instances --instance-ids $(terraform output -raw instance_id)

# Check user-data logs
ssh ubuntu@$(terraform output -raw public_ip) 'tail -f /var/log/user-data.log'
```

**4. Performance issues:**
```bash
# Verify instance type supports high bandwidth
aws ec2 describe-instance-types --instance-types $(terraform output -raw instance_type)

# Check if enhanced networking is enabled
aws ec2 describe-instance-attribute --instance-id $(terraform output -raw instance_id) --attribute enaSupport
```

## 📚 Advanced Features

### CloudWatch Monitoring
```hcl
enable_monitoring = true
log_retention_days = 30
sns_topic_arn = "arn:aws:sns:region:account:alerts"  # For notifications
```

### Placement Groups (Multiple Instances)
```hcl
enable_placement_group = true
placement_group_strategy = "cluster"  # For consistent performance
```

### Auto-Scaling (Future Enhancement)
```hcl
enable_auto_scaling = true
min_instances = 1
max_instances = 3
```

## 🔗 Outputs Reference

After deployment, these outputs are available:

| Output                 | Description              |
|------------------------|--------------------------|
| `public_ip`            | Server public IP address |
| `instance_id`          | EC2 instance ID          |
| `ssh_command`          | SSH connection command   |
| `iperf3_test_commands` | Quick test commands      |
| `aws_console_links`    | Direct AWS console links |
| `connection_info`      | Formatted summary        |

## 📞 Support

- **Terraform Issues**: Check [Terraform documentation](https://terraform.io/docs)
- **AWS Issues**: See [AWS EC2 documentation](https://docs.aws.amazon.com/ec2/)
- **iPerf3 Issues**: Review [main project README](../README.md)
- **Performance Questions**: Check the [AWS deployment guide](../README-AWS.md)

---

**Quick Commands Summary:**
```bash
# Deploy
terraform init && terraform apply

# Test
iperf3 -c $(terraform output -raw public_ip) -p 5201 -R -t 30 -P 4

# Stop
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)

# Destroy
terraform destroy
```
