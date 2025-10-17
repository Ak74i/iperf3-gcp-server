# iPerf3 High-Speed Test Server for Amazon Web Services (AWS)

[![AWS](https://img.shields.io/badge/AWS-Ready-FF9900?logo=amazon-aws)](https://aws.amazon.com)
[![iPerf3](https://img.shields.io/badge/iPerf3-Optimized-success)](https://iperf.fr/)

Complete guide for deploying an iPerf3 high-speed test server (3+ Gbps capable) on Amazon Web Services.

## Quick Start ##

**One-command deployment:**
```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/iperf3-multicloud-server/main/deploy-aws.sh | bash
```

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Setup](#quick-setup)
3. [Manual Setup](#manual-setup)
4. [Terraform Deployment](#terraform-deployment)
5. [Testing](#testing)
6. [Cost Management](#cost-management)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools
- **AWS CLI v2** - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Terraform** (optional) - [Download](https://terraform.io/downloads)
- **SSH Client** - Built into most systems

### AWS Account Setup
1. **Create AWS Account** - [Sign up here](https://aws.amazon.com/free/)
2. **Configure AWS CLI:**
   ```bash
   aws configure
   ```
   Enter your:
   - Access Key ID
   - Secret Access Key
   - Default region: `eu-west-2` (London)
   - Default output format: `json`

3. **Verify Configuration:**
   ```bash
   aws sts get-caller-identity
   ```

## Quick Setup ##

### Option 1: Automated Deployment Script

**Download and run the deployment script:**
```bash
# Download the script
wget https://raw.githubusercontent.com/YOUR_USERNAME/iperf3-multicloud-server/main/deploy-aws.sh

# Make it executable
chmod +x deploy-aws.sh

# Run with defaults (London region, c5n.xlarge)
./deploy-aws.sh

# Or customize the deployment
./deploy-aws.sh --region us-east-1 --instance-type c5n.2xlarge --name my-iperf-test
```

**Script will:**
1. ✅ Create security group with iPerf3 ports
2. ✅ Launch optimized EC2 instance
3. ✅ Install and configure iPerf3 servers (5 instances)
4. ✅ Set up auto-start on boot
5. ✅ Display connection details

## 🔧 Manual Setup

### Step 1: Create Security Group

```bash
# Create security group
aws ec2 create-security-group \
    --group-name iperf3-server-sg \
    --description "iPerf3 test server security group" \
    --region eu-west-2

# Add SSH access (replace YOUR_IP with your public IP)
aws ec2 authorize-security-group-ingress \
    --group-name iperf3-server-sg \
    --protocol tcp \
    --port 22 \
    --cidr YOUR_IP/32 \
    --region eu-west-2

# Add iPerf3 ports (TCP & UDP)
for port in 5201 5202 5203 5204 5205; do
    aws ec2 authorize-security-group-ingress \
        --group-name iperf3-server-sg \
        --protocol tcp \
        --port $port \
        --cidr 0.0.0.0/0 \
        --region eu-west-2
    
    aws ec2 authorize-security-group-ingress \
        --group-name iperf3-server-sg \
        --protocol udp \
        --port $port \
        --cidr 0.0.0.0/0 \
        --region eu-west-2
done
```

### Step 2: Launch EC2 Instance

**Recommended instance types for 3+ Gbps:** (prices in USD)

| Instance Type   | vCPUs | RAM     | Network Performance | Hourly Cost (London) |
|-----------------|-------|---------|---------------------|----------------------|
| **c5n.xlarge**  | 4     | 10.5 GB | Up to 25 Gbps       | ~$0.22               |
| **c5n.2xlarge** | 8     | 21 GB   | Up to 25 Gbps       | ~$0.43               |
| **m5n.xlarge**  | 4     | 16 GB   | Up to 25 Gbps       | ~$0.24               |
| **c5n.large**   | 2     | 5.25 GB | Up to 10 Gbps       | ~$0.11               |

```bash
# Get latest Ubuntu 22.04 AMI ID
AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text \
    --region eu-west-2)

# Launch instance
aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type c5n.xlarge \
    --key-name YOUR_KEY_PAIR \
    --security-groups iperf3-server-sg \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=iPerf3-Test-Server}]' \
    --user-data file://aws-user-data.sh \
    --region eu-west-2
```

### Step 3: Configure Server (Auto-setup via User Data)

The `aws-user-data.sh` script automatically configures the server:

```bash
#!/bin/bash
# This script runs automatically when instance starts

# Update system
apt-get update -y
apt-get upgrade -y

# Install iPerf3
apt-get install -y iperf3 htop

# Create systemd services for 5 iPerf3 instances
for i in {1..5}; do
    port=$((5200 + i))
    
    cat > /etc/systemd/system/iperf3-${i}.service << EOF
[Unit]
Description=iPerf3 server instance ${i}
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/bin/iperf3 -s -p ${port} -D
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl enable iperf3-${i}.service
    systemctl start iperf3-${i}.service
done

# Optimize network settings
cat >> /etc/sysctl.conf << EOF
# Network optimizations for iPerf3
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 5000
EOF

sysctl -p

# Create status script
cat > /usr/local/bin/iperf3-status << 'EOF'
#!/bin/bash
echo "==================== iPerf3 Server Status ===================="
echo "Server IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
echo "Region: $(curl -s http://169.254.169.254/latest/meta-data/placement/region)"
echo "=============================================================="
for i in {1..5}; do
    port=$((5200 + i))
    status=$(systemctl is-active iperf3-${i}.service)
    echo "iPerf3 Instance ${i} (port ${port}): ${status}"
done
echo "=============================================================="
echo "Quick Test Commands:"
echo "  Download Test: iperf3 -c \$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) -p 5201 -R -t 30"
echo "  Upload Test:   iperf3 -c \$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) -p 5201 -t 30"
echo "  UDP Test:      iperf3 -c \$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) -p 5201 -u -b 3G -R -t 30"
echo "=============================================================="
EOF

chmod +x /usr/local/bin/iperf3-status

# Log completion
echo "iPerf3 server setup completed at $(date)" >> /var/log/iperf3-setup.log
```

## 🏗️ Terraform Deployment

For infrastructure-as-code deployment, use the Terraform configuration:

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/iperf3-multicloud-server.git
cd iperf3-multicloud-server/terraform-aws

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

**Terraform will create:**
- ✅ VPC with public subnet
- ✅ Security group with proper rules
- ✅ EC2 instance with optimized settings
- ✅ Elastic IP (optional)
- ✅ All necessary networking

## 🧪 Testing Your Server

### Get Server Information

**SSH into your instance:**
```bash
# Get instance IP
INSTANCE_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=iPerf3-Test-Server" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region eu-west-2)

# SSH to server
ssh ubuntu@$INSTANCE_IP

# Check server status
sudo /usr/local/bin/iperf3-status
```

### Basic Performance Tests

**Download Speed Test (3 Gbps target):**
```bash
iperf3 -c SERVER_IP -p 5201 -R -t 60 -P 4
```

**Upload Speed Test:**
```bash
iperf3 -c SERVER_IP -p 5201 -t 60 -P 4
```

**UDP Test (High bandwidth):**
```bash
iperf3 -c SERVER_IP -p 5201 -u -b 3G -R -t 60
```

### Advanced Testing

**Parallel connections across multiple ports:**
```bash
# Test all 5 server instances simultaneously
for port in {5201..5205}; do
    iperf3 -c SERVER_IP -p $port -t 30 -P 2 &
done
wait
```

**Continuous monitoring:**
```bash
# On server - monitor in real-time
htop  # CPU and memory
iftop # Network usage (install with: apt install iftop)
```

## 💰 Cost Management

### Instance Pricing (London - eu-west-2)

| Instance Type    | On-Demand (per hour) | Spot (per hour) | Monthly (24/7) |
|------------------|----------------------|-----------------|----------------|
| **c5n.large**    | $0.108               | ~$0.032         | ~$78           |
| **c5n.xlarge**   | $0.216               | ~$0.065         | ~$156          |
| **c5n.2xlarge**  | $0.432               | ~$0.130         | ~$312          |

### Cost Optimization Tips

**1. Use Spot Instances (60-70% savings):**
```bash
# Launch spot instance
aws ec2 request-spot-instances \
    --spot-price "0.065" \
    --instance-count 1 \
    --type "one-time" \
    --launch-specification file://spot-launch-spec.json
```

**2. Stop instance when not testing:**
```bash
# Stop instance
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# Start when needed
aws ec2 start-instances --instance-ids i-1234567890abcdef0
```

**3. Scheduled testing:**
```bash
# Use AWS Systems Manager to schedule start/stop
aws ssm send-command \
    --document-name "AWS-StopEC2Instance" \
    --instance-ids "i-1234567890abcdef0"
```

## ⚠️ Important Cost Warning

> **💸 COST ALERT**: Running 24/7 can cost $150-300+ per month! Always stop instances when not testing.

### Automatic Cleanup

Set up CloudWatch alarms to auto-stop idle instances:

```bash
# Create CloudWatch alarm for low CPU
aws cloudwatch put-metric-alarm \
    --alarm-name "iPerf3-Low-CPU" \
    --alarm-description "Stop instance if CPU < 5% for 30 minutes" \
    --metric-name CPUUtilization \
    --namespace AWS/EC2 \
    --statistic Average \
    --period 300 \
    --threshold 5.0 \
    --comparison-operator LessThanThreshold \
    --evaluation-periods 6 \
    --alarm-actions arn:aws:automate:eu-west-2:ec2:stop
```

## 🔧 Troubleshooting

### Common Issues

**1. Can't connect to server:**
```bash
# Check security group
aws ec2 describe-security-groups --group-names iperf3-server-sg

# Verify instance is running
aws ec2 describe-instances --filters "Name=tag:Name,Values=iPerf3-Test-Server"
```

**2. Low performance:**
```bash
# Check instance type supports high bandwidth
aws ec2 describe-instance-types --instance-types c5n.xlarge --query 'InstanceTypes[0].NetworkInfo'

# Verify enhanced networking is enabled
aws ec2 describe-instance-attribute --instance-id i-1234567890abcdef0 --attribute enaSupport
```

**3. iPerf3 not running:**
```bash
# SSH to server and check services
sudo systemctl status iperf3-1.service
sudo journalctl -u iperf3-1.service -f

# Restart if needed
sudo systemctl restart iperf3-{1..5}.service
```

### Performance Optimization

**Enable enhanced networking:**
```bash
# Stop instance first
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# Enable enhanced networking
aws ec2 modify-instance-attribute \
    --instance-id i-1234567890abcdef0 \
    --ena-support
```

**Check placement group (for multiple instances):**
```bash
# Create cluster placement group
aws ec2 create-placement-group \
    --group-name iperf3-cluster \
    --strategy cluster
```

## 📚 Additional Resources

- **AWS EC2 Network Performance Guide**: [AWS Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking.html)
- **iPerf3 Official Documentation**: [iPerf.fr](https://iperf.fr/iperf-doc.php)
- **AWS CLI Reference**: [AWS CLI Docs](https://docs.aws.amazon.com/cli/)

## 🤝 Contributing

Found an issue or want to contribute? Please visit our [main repository](https://github.com/YOUR_USERNAME/iperf3-multicloud-server).

---

**📧 Support**: Create an issue on GitHub for help with deployment or performance questions.

**🔄 Updates**: Star the repository to get notified of improvements and new cloud provider support!
