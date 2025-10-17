#!/bin/bash

# iPerf3 AWS Deployment Script
# Automated setup for high-speed network testing server on AWS
# Supports 3+ Gbps throughput testing

set -euo pipefail

# Default configuration
DEFAULT_REGION="eu-west-2"
DEFAULT_INSTANCE_TYPE="c5n.xlarge"
DEFAULT_KEY_NAME=""
DEFAULT_SERVER_NAME="iPerf3-Test-Server"
DEFAULT_SPOT_PRICE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="1.0.0"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Help function
show_help() {
    cat << EOF
iPerf3 AWS Deployment Script v${VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -r, --region REGION          AWS region (default: ${DEFAULT_REGION})
    -t, --instance-type TYPE     EC2 instance type (default: ${DEFAULT_INSTANCE_TYPE})
    -k, --key-name NAME          EC2 key pair name (required)
    -n, --name NAME              Server name tag (default: ${DEFAULT_SERVER_NAME})
    -s, --spot-price PRICE       Use spot instance with max price
    -h, --help                   Show this help message
    -v, --version                Show version

RECOMMENDED INSTANCE TYPES:
    c5n.large    - 2 vCPU,  5.25GB RAM, Up to 10 Gbps  (~\$0.11/hr)
    c5n.xlarge   - 4 vCPU, 10.50GB RAM, Up to 25 Gbps  (~\$0.22/hr) ⭐ RECOMMENDED
    c5n.2xlarge  - 8 vCPU, 21.00GB RAM, Up to 25 Gbps  (~\$0.43/hr)
    m5n.xlarge   - 4 vCPU, 16.00GB RAM, Up to 25 Gbps  (~\$0.24/hr)

EXAMPLES:
    # Basic deployment with defaults
    $0 --key-name my-key-pair

    # Custom region and instance type
    $0 --region us-east-1 --instance-type c5n.2xlarge --key-name my-key

    # Spot instance deployment (60-70% cost savings)
    $0 --key-name my-key --spot-price 0.065

PREREQUISITES:
    - AWS CLI configured with appropriate permissions
    - EC2 key pair created in target region
    - Internet connection for downloading packages

EOF
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first:"
        print_error "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    # Check if jq is available (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Installing basic JSON parsing..."
        # We'll use grep/sed instead of jq for basic parsing
    fi
    
    print_success "Prerequisites check passed"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -t|--instance-type)
                INSTANCE_TYPE="$2"
                shift 2
                ;;
            -k|--key-name)
                KEY_NAME="$2"
                shift 2
                ;;
            -n|--name)
                SERVER_NAME="$2"
                shift 2
                ;;
            -s|--spot-price)
                SPOT_PRICE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "iPerf3 AWS Deployment Script v${VERSION}"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set defaults if not provided
    REGION=${REGION:-$DEFAULT_REGION}
    INSTANCE_TYPE=${INSTANCE_TYPE:-$DEFAULT_INSTANCE_TYPE}
    SERVER_NAME=${SERVER_NAME:-$DEFAULT_SERVER_NAME}
    SPOT_PRICE=${SPOT_PRICE:-$DEFAULT_SPOT_PRICE}
    
    # Validate required parameters
    if [[ -z "${KEY_NAME:-}" ]]; then
        print_error "Key pair name is required. Use --key-name option."
        exit 1
    fi
}

# Get your public IP for SSH access
get_public_ip() {
    print_status "Getting your public IP for SSH access..."
    PUBLIC_IP=$(curl -s https://ipinfo.io/ip || curl -s https://icanhazip.com || echo "0.0.0.0")
    if [[ "$PUBLIC_IP" == "0.0.0.0" ]]; then
        print_warning "Could not determine your public IP. SSH access will be open to 0.0.0.0/0"
        SSH_CIDR="0.0.0.0/0"
    else
        SSH_CIDR="${PUBLIC_IP}/32"
        print_success "Detected public IP: $PUBLIC_IP"
    fi
}

# Create security group
create_security_group() {
    print_status "Creating security group..."
    
    SG_NAME="iperf3-server-sg-$(date +%s)"
    
    # Create security group
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SG_NAME" \
        --description "iPerf3 test server security group" \
        --region "$REGION" \
        --output text --query 'GroupId' 2>/dev/null || echo "")
    
    if [[ -z "$SG_ID" ]]; then
        print_error "Failed to create security group"
        exit 1
    fi
    
    print_success "Created security group: $SG_ID"
    
    # Add SSH rule
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr "$SSH_CIDR" \
        --region "$REGION" > /dev/null
    
    # Add iPerf3 ports (5201-5205 TCP and UDP)
    for port in 5201 5202 5203 5204 5205; do
        # TCP
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port "$port" \
            --cidr "0.0.0.0/0" \
            --region "$REGION" > /dev/null
        
        # UDP
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol udp \
            --port "$port" \
            --cidr "0.0.0.0/0" \
            --region "$REGION" > /dev/null
    done
    
    print_success "Security group configured with iPerf3 ports"
}

# Create user data script
create_user_data() {
    cat > /tmp/iperf3-user-data.sh << 'EOF'
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting iPerf3 server setup at $(date)"

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y iperf3 htop iftop tcpdump net-tools

# Optimize network settings
cat >> /etc/sysctl.conf << 'SYSCTL_EOF'
# Network optimizations for iPerf3
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
SYSCTL_EOF

sysctl -p

# Create systemd services for 5 iPerf3 instances
for i in {1..5}; do
    port=$((5200 + i))
    
    cat > /etc/systemd/system/iperf3-${i}.service << SERVICE_EOF
[Unit]
Description=iPerf3 server instance ${i} on port ${port}
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/bin/iperf3 -s -p ${port}
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    # Enable and start service
    systemctl enable iperf3-${i}.service
    systemctl start iperf3-${i}.service
done

# Wait for services to start
sleep 5

# Create status and management scripts
cat > /usr/local/bin/iperf3-status << 'STATUS_EOF'
#!/bin/bash
echo "==================== iPerf3 Server Status ===================="
echo "Server IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
echo "Region: $(curl -s http://169.254.169.254/latest/meta-data/placement/region)"
echo "Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
echo "=============================================================="
echo "Service Status:"
for i in {1..5}; do
    port=$((5200 + i))
    status=$(systemctl is-active iperf3-${i}.service)
    if [[ "$status" == "active" ]]; then
        echo "  ✅ iPerf3 Instance ${i} (port ${port}): ${status}"
    else
        echo "  ❌ iPerf3 Instance ${i} (port ${port}): ${status}"
    fi
done
echo "=============================================================="
echo "Quick Test Commands:"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "  Download Test: iperf3 -c ${PUBLIC_IP} -p 5201 -R -t 30"
echo "  Upload Test:   iperf3 -c ${PUBLIC_IP} -p 5201 -t 30"
echo "  UDP Test:      iperf3 -c ${PUBLIC_IP} -p 5201 -u -b 3G -R -t 30"
echo "  Parallel Test: iperf3 -c ${PUBLIC_IP} -p 5201 -P 4 -R -t 30"
echo "=============================================================="
STATUS_EOF

chmod +x /usr/local/bin/iperf3-status

# Create performance test script
cat > /usr/local/bin/iperf3-test << 'TEST_EOF'
#!/bin/bash
echo "Running comprehensive iPerf3 performance test..."
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "1. Single connection TCP download test:"
iperf3 -c localhost -p 5201 -R -t 10

echo "2. Parallel connections TCP download test:"
iperf3 -c localhost -p 5201 -R -t 10 -P 4

echo "3. UDP test at 3 Gbps:"
iperf3 -c localhost -p 5201 -u -b 3G -R -t 10

echo "Test completed. Use these commands from remote clients:"
echo "  iperf3 -c ${PUBLIC_IP} -p 5201 -R -t 30 -P 4"
TEST_EOF

chmod +x /usr/local/bin/iperf3-test

# Add aliases for convenience
cat >> /home/ubuntu/.bashrc << 'BASHRC_EOF'
alias iperf3-status='/usr/local/bin/iperf3-status'
alias iperf3-test='/usr/local/bin/iperf3-test'
alias iperf3-restart='sudo systemctl restart iperf3-{1..5}.service'
BASHRC_EOF

# Log completion
echo "iPerf3 server setup completed successfully at $(date)" >> /var/log/iperf3-setup.log
echo "Setup completed. Running status check..."
/usr/local/bin/iperf3-status

# Signal completion
echo "IPERF3_SETUP_COMPLETE" > /tmp/setup-complete
EOF

    base64 -w 0 /tmp/iperf3-user-data.sh > /tmp/iperf3-user-data-b64.txt
}

# Get latest Ubuntu AMI
get_ubuntu_ami() {
    print_status "Finding latest Ubuntu 22.04 AMI in $REGION..."
    
    AMI_ID=$(aws ec2 describe-images \
        --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
        print_error "Could not find Ubuntu 22.04 AMI in region $REGION"
        exit 1
    fi
    
    print_success "Found Ubuntu AMI: $AMI_ID"
}

# Launch instance
launch_instance() {
    print_status "Launching EC2 instance..."
    
    if [[ -n "$SPOT_PRICE" ]]; then
        print_status "Launching spot instance with max price: \$$SPOT_PRICE"
        launch_spot_instance
    else
        print_status "Launching on-demand instance"
        launch_ondemand_instance
    fi
}

launch_ondemand_instance() {
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SG_ID" \
        --user-data file:///tmp/iperf3-user-data-b64.txt \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$SERVER_NAME},{Key=Project,Value=iPerf3-Testing},{Key=CreatedBy,Value=iperf3-deploy-script}]" \
        --instance-initiated-shutdown-behavior terminate \
        --region "$REGION" \
        --output text --query 'Instances[0].InstanceId' 2>/dev/null || echo "")
    
    if [[ -z "$INSTANCE_ID" ]]; then
        print_error "Failed to launch instance"
        exit 1
    fi
    
    print_success "Launched instance: $INSTANCE_ID"
}

launch_spot_instance() {
    # Create launch template first
    TEMPLATE_NAME="iperf3-template-$(date +%s)"
    
    aws ec2 create-launch-template \
        --launch-template-name "$TEMPLATE_NAME" \
        --launch-template-data "{
            \"ImageId\":\"$AMI_ID\",
            \"InstanceType\":\"$INSTANCE_TYPE\",
            \"KeyName\":\"$KEY_NAME\",
            \"SecurityGroupIds\":[\"$SG_ID\"],
            \"UserData\":\"$(cat /tmp/iperf3-user-data-b64.txt)\",
            \"TagSpecifications\":[{
                \"ResourceType\":\"instance\",
                \"Tags\":[
                    {\"Key\":\"Name\",\"Value\":\"$SERVER_NAME\"},
                    {\"Key\":\"Project\",\"Value\":\"iPerf3-Testing\"},
                    {\"Key\":\"CreatedBy\",\"Value\":\"iperf3-deploy-script\"},
                    {\"Key\":\"InstanceType\",\"Value\":\"spot\"}
                ]
            }]
        }" \
        --region "$REGION" > /dev/null
    
    # Request spot instance
    SPOT_REQUEST_ID=$(aws ec2 request-spot-instances \
        --spot-price "$SPOT_PRICE" \
        --instance-count 1 \
        --type "one-time" \
        --launch-template "{\"LaunchTemplateName\":\"$TEMPLATE_NAME\"}" \
        --region "$REGION" \
        --output text --query 'SpotInstanceRequests[0].SpotInstanceRequestId' 2>/dev/null || echo "")
    
    if [[ -z "$SPOT_REQUEST_ID" ]]; then
        print_error "Failed to request spot instance"
        exit 1
    fi
    
    print_success "Spot instance requested: $SPOT_REQUEST_ID"
    print_status "Waiting for spot instance to be fulfilled..."
    
    # Wait for spot request to be fulfilled
    for i in {1..60}; do
        INSTANCE_ID=$(aws ec2 describe-spot-instance-requests \
            --spot-instance-request-ids "$SPOT_REQUEST_ID" \
            --region "$REGION" \
            --output text --query 'SpotInstanceRequests[0].InstanceId' 2>/dev/null || echo "")
        
        if [[ "$INSTANCE_ID" != "None" && -n "$INSTANCE_ID" ]]; then
            print_success "Spot instance fulfilled: $INSTANCE_ID"
            break
        fi
        
        echo -n "."
        sleep 5
    done
    
    if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
        print_error "Spot instance request timed out"
        exit 1
    fi
}

# Wait for instance to be ready
wait_for_instance() {
    print_status "Waiting for instance to be running..."
    
    aws ec2 wait instance-running \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION"
    
    print_success "Instance is running"
    
    # Get instance details
    INSTANCE_INFO=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'Reservations[0].Instances[0]' 2>/dev/null || echo "")
    
    if [[ -z "$INSTANCE_INFO" ]]; then
        print_error "Could not get instance information"
        exit 1
    fi
    
    PUBLIC_IP=$(echo "$INSTANCE_INFO" | grep -o '"PublicIpAddress": "[^"]*"' | cut -d'"' -f4)
    PRIVATE_IP=$(echo "$INSTANCE_INFO" | grep -o '"PrivateIpAddress": "[^"]*"' | cut -d'"' -f4)
    AZ=$(echo "$INSTANCE_INFO" | grep -o '"AvailabilityZone": "[^"]*"' | cut -d'"' -f4)
    
    print_success "Instance is ready!"
    print_status "Public IP: $PUBLIC_IP"
    print_status "Private IP: $PRIVATE_IP"
    print_status "Availability Zone: $AZ"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for iPerf3 services to start (this may take 2-3 minutes)..."
    
    for i in {1..60}; do
        # Check if setup is complete
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
           ubuntu@"$PUBLIC_IP" "test -f /tmp/setup-complete" 2>/dev/null; then
            print_success "Server setup completed!"
            break
        fi
        
        if [[ $i -eq 60 ]]; then
            print_warning "Setup verification timed out, but instance should be ready soon"
            break
        fi
        
        echo -n "."
        sleep 5
    done
    
    # Brief additional wait for services to fully start
    sleep 10
}

# Run basic connectivity test
test_connectivity() {
    print_status "Testing iPerf3 connectivity..."
    
    # Test if we can connect to SSH
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
       ubuntu@"$PUBLIC_IP" "echo 'SSH connection successful'" 2>/dev/null; then
        print_success "SSH connection successful"
    else
        print_warning "SSH connection failed - check your key pair and security group"
    fi
    
    # Test iPerf3 port
    if nc -z -w5 "$PUBLIC_IP" 5201 2>/dev/null; then
        print_success "iPerf3 port 5201 is accessible"
    else
        print_warning "iPerf3 port 5201 not yet accessible - services may still be starting"
    fi
}

# Display final information
show_completion_info() {
    echo
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    🎉 DEPLOYMENT SUCCESSFUL! 🎉                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo
    echo "📋 Server Details:"
    echo "  • Instance ID:    $INSTANCE_ID"
    echo "  • Instance Type:  $INSTANCE_TYPE"
    echo "  • Region:         $REGION"
    echo "  • Public IP:      $PUBLIC_IP"
    echo "  • Security Group: $SG_ID"
    if [[ -n "$SPOT_PRICE" ]]; then
        echo "  • Type:           Spot Instance (max \$$SPOT_PRICE/hour)"
    else
        echo "  • Type:           On-Demand Instance"
    fi
    echo
    echo "🧪 Quick Test Commands:"
    echo "  # Download test (3+ Gbps capable)"
    echo "  iperf3 -c $PUBLIC_IP -p 5201 -R -t 30 -P 4"
    echo
    echo "  # Upload test"
    echo "  iperf3 -c $PUBLIC_IP -p 5201 -t 30 -P 4"
    echo
    echo "  # UDP test"
    echo "  iperf3 -c $PUBLIC_IP -p 5201 -u -b 3G -R -t 30"
    echo
    echo "🔧 Server Management:"
    echo "  # SSH to server"
    echo "  ssh ubuntu@$PUBLIC_IP"
    echo
    echo "  # Check server status"
    echo "  ssh ubuntu@$PUBLIC_IP 'iperf3-status'"
    echo
    echo "  # Stop instance (SAVE MONEY!)"
    echo "  aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $REGION"
    echo
    echo "  # Start instance"
    echo "  aws ec2 start-instances --instance-ids $INSTANCE_ID --region $REGION"
    echo
    echo "  # Terminate instance (DELETE PERMANENTLY)"
    echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
    echo
    echo "💰 Cost Management:"
    if [[ -n "$SPOT_PRICE" ]]; then
        echo "  • Spot instance: ~\$$SPOT_PRICE/hour (60-70% savings)"
    else
        HOURLY_COST=$(get_hourly_cost "$INSTANCE_TYPE")
        echo "  • On-demand: ~\$$HOURLY_COST/hour"
    fi
    echo "  • Remember to STOP the instance when not testing!"
    echo
    echo "🌐 AWS Console:"
    echo "  https://$REGION.console.aws.amazon.com/ec2/v2/home?region=$REGION#Instances:instanceId=$INSTANCE_ID"
    echo
    echo "📚 Documentation:"
    echo "  • AWS Guide: README-AWS.md"
    echo "  • GitHub: https://github.com/YOUR_USERNAME/iperf3-multicloud-server"
    echo
    print_success "Deployment completed! Server is ready for high-speed testing."
}

# Get estimated hourly cost
get_hourly_cost() {
    case $1 in
        "c5n.large") echo "0.11" ;;
        "c5n.xlarge") echo "0.22" ;;
        "c5n.2xlarge") echo "0.43" ;;
        "m5n.xlarge") echo "0.24" ;;
        *) echo "0.20" ;;
    esac
}

# Cleanup function for interrupted deployments
cleanup_on_error() {
    print_error "Deployment failed or was interrupted"
    
    if [[ -n "${SG_ID:-}" ]]; then
        print_status "Cleaning up security group..."
        aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION" 2>/dev/null || true
    fi
    
    if [[ -n "${INSTANCE_ID:-}" ]]; then
        print_status "Terminating instance..."
        aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$REGION" 2>/dev/null || true
    fi
    
    exit 1
}

# Set trap for cleanup
trap cleanup_on_error ERR INT TERM

# Main execution
main() {
    echo "iPerf3 AWS Deployment Script v${VERSION}"
    echo "==========================================="
    
    # Parse command line arguments
    parse_args "$@"
    
    # Run deployment steps
    check_prerequisites
    get_public_ip
    create_security_group
    create_user_data
    get_ubuntu_ami
    launch_instance
    wait_for_instance
    wait_for_services
    test_connectivity
    show_completion_info
    
    # Cleanup temporary files
    rm -f /tmp/iperf3-user-data.sh /tmp/iperf3-user-data-b64.txt
}

# Run main function with all arguments
main "$@"
