#!/bin/bash

# iPerf3 GCP Deployment Script
# Automated setup for high-speed network testing server on Google Cloud Platform
# Supports 3+ Gbps throughput testing

set -euo pipefail

# Default configuration
DEFAULT_PROJECT=""
DEFAULT_REGION="europe-west2"
DEFAULT_ZONE="europe-west2-a"
DEFAULT_MACHINE_TYPE="n2-standard-4"
DEFAULT_SERVER_NAME="iperf3-server"
DEFAULT_PREEMPTIBLE="false"

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
iPerf3 GCP Deployment Script v${VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -p, --project PROJECT        GCP project ID (required)
    -r, --region REGION          GCP region (default: ${DEFAULT_REGION})
    -z, --zone ZONE              GCP zone (default: ${DEFAULT_ZONE})
    -m, --machine-type TYPE      Machine type (default: ${DEFAULT_MACHINE_TYPE})
    -n, --name NAME              Server name (default: ${DEFAULT_SERVER_NAME})
    --preemptible                Use preemptible instance (70% cost savings)
    -h, --help                   Show this help message
    -v, --version                Show version

RECOMMENDED MACHINE TYPES (Europe Compatible):
    e2-standard-4   - 4 vCPU, 16.0GB RAM, Up to 4 Gbps   (~€0.13/hr)
    n2-standard-4   - 4 vCPU, 16.0GB RAM, Up to 10 Gbps  (~€0.17/hr) ⭐ RECOMMENDED
    n2-highcpu-8    - 8 vCPU,  8.0GB RAM, Up to 16 Gbps  (~€0.28/hr)
    n2-standard-8   - 8 vCPU, 32.0GB RAM, Up to 16 Gbps  (~€0.35/hr)

EXAMPLES:
    # Basic deployment
    $0 --project my-gcp-project --region europe-west2

    # Cost-optimized with preemptible instance
    $0 --project my-project --region europe-west1 --preemptible

    # High-performance setup
    $0 --project my-project --machine-type n2-highcpu-8

PREREQUISITES:
    - gcloud CLI installed and configured
    - GCP project with Compute Engine API enabled
    - Internet connection for downloading packages

EOF
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed. Please install it first:"
        print_error "https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check if gcloud is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &> /dev/null; then
        print_error "gcloud is not authenticated. Please run 'gcloud auth login' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project)
                PROJECT="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -z|--zone)
                ZONE="$2"
                shift 2
                ;;
            -m|--machine-type)
                MACHINE_TYPE="$2"
                shift 2
                ;;
            -n|--name)
                SERVER_NAME="$2"
                shift 2
                ;;
            --preemptible)
                PREEMPTIBLE="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "iPerf3 GCP Deployment Script v${VERSION}"
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
    PROJECT=${PROJECT:-$DEFAULT_PROJECT}
    REGION=${REGION:-$DEFAULT_REGION}
    ZONE=${ZONE:-$DEFAULT_ZONE}
    MACHINE_TYPE=${MACHINE_TYPE:-$DEFAULT_MACHINE_TYPE}
    SERVER_NAME=${SERVER_NAME:-$DEFAULT_SERVER_NAME}
    PREEMPTIBLE=${PREEMPTIBLE:-$DEFAULT_PREEMPTIBLE}
    
    # Validate required parameters
    if [[ -z "${PROJECT}" ]]; then
        print_error "GCP project ID is required. Use --project option."
        exit 1
    fi
}

# Create firewall rule
create_firewall_rule() {
    print_status "Creating firewall rule..."
    
    FIREWALL_NAME="${SERVER_NAME}-firewall"
    
    # Check if firewall rule already exists
    if gcloud compute firewall-rules describe "$FIREWALL_NAME" --project="$PROJECT" &>/dev/null; then
        print_warning "Firewall rule $FIREWALL_NAME already exists"
    else
        gcloud compute firewall-rules create "$FIREWALL_NAME" \
            --project="$PROJECT" \
            --allow tcp:22,tcp:5201-5205,udp:5201-5205 \
            --source-ranges 0.0.0.0/0 \
            --description "iPerf3 test server firewall rule" \
            --target-tags iperf3-server
        
        print_success "Created firewall rule: $FIREWALL_NAME"
    fi
}

# Create startup script
create_startup_script() {
    cat > /tmp/iperf3-startup-script.sh << 'EOF'
#!/bin/bash
# iPerf3 Server Setup Script for GCP

exec > >(tee /var/log/startup-script.log) 2>&1

echo "Starting iPerf3 server setup at $(date)"

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install packages
sudo apt-get install -y iperf3 htop iftop net-tools

# Network optimizations
sudo cat >> /etc/sysctl.conf << 'SYSCTL_EOF'
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456
net.core.netdev_max_backlog = 5000
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
SYSCTL_EOF

sudo sysctl -p

# Create iPerf3 services
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

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    systemctl enable iperf3-${i}.service
    systemctl start iperf3-${i}.service
done

# Create status script
cat > /usr/local/bin/iperf3-status << 'STATUS_EOF'
#!/bin/bash
echo "==================== iPerf3 Server Status ===================="
echo "External IP: $(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
echo "Internal IP: $(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)"
echo "Machine Type: $(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/machine-type | cut -d'/' -f4)"
echo "Zone: $(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d'/' -f4)"
echo "=============================================================="
echo "Service Status:"
for i in {1..5}; do
    port=$((5200 + i))
    status=$(systemctl is-active iperf3-${i}.service)
    echo "  iPerf3 Instance ${i} (port ${port}): ${status}"
done
echo "=============================================================="
EXTERNAL_IP=$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
echo "Quick Test Commands:"
echo "  Download: iperf3 -c ${EXTERNAL_IP} -p 5201 -R -t 30 -P 4"
echo "  Upload:   iperf3 -c ${EXTERNAL_IP} -p 5201 -t 30 -P 4"
echo "  UDP:      iperf3 -c ${EXTERNAL_IP} -p 5201 -u -b 3G -R -t 30"
echo "=============================================================="
STATUS_EOF

chmod +x /usr/local/bin/iperf3-status

# Create aliases
cat >> /home/ubuntu/.bashrc << 'BASHRC_EOF'
alias iperf3-status='/usr/local/bin/iperf3-status'
alias iperf3-restart='sudo systemctl restart iperf3-{1..5}.service'
alias iperf3-logs='sudo journalctl -u iperf3-*.service -f'
BASHRC_EOF

echo "iPerf3 server setup completed at $(date)"
echo "IPERF3_SETUP_COMPLETE" > /tmp/setup-complete
EOF
}

# Create instance
create_instance() {
    print_status "Creating GCP instance..."
    
    # Prepare preemptible flag
    PREEMPTIBLE_FLAG=""
    if [[ "$PREEMPTIBLE" == "true" ]]; then
        PREEMPTIBLE_FLAG="--preemptible"
        print_warning "Using preemptible instance (can be terminated at any time)"
    fi
    
    # Create instance
    gcloud compute instances create "$SERVER_NAME" \
        --project="$PROJECT" \
        --zone="$ZONE" \
        --machine-type="$MACHINE_TYPE" \
        --image-family=ubuntu-2204-lts \
        --image-project=ubuntu-os-cloud \
        --boot-disk-size=20GB \
        --boot-disk-type=pd-standard \
        --tags=iperf3-server \
        --metadata-from-file startup-script=/tmp/iperf3-startup-script.sh \
        $PREEMPTIBLE_FLAG
    
    print_success "Created instance: $SERVER_NAME"
    
    # Clean up startup script
    rm -f /tmp/iperf3-startup-script.sh
}

# Wait for instance to be ready
wait_for_instance() {
    print_status "Waiting for instance to be ready..."
    
    # Wait for instance to be running
    while true; do
        STATUS=$(gcloud compute instances describe "$SERVER_NAME" --zone="$ZONE" --project="$PROJECT" --format="value(status)")
        if [[ "$STATUS" == "RUNNING" ]]; then
            break
        fi
        echo -n "."
        sleep 5
    done
    
    print_success "Instance is running!"
    
    # Get instance details
    EXTERNAL_IP=$(gcloud compute instances describe "$SERVER_NAME" --zone="$ZONE" --project="$PROJECT" --format="value(networkInterfaces[0].accessConfigs[0].natIP)")
    INTERNAL_IP=$(gcloud compute instances describe "$SERVER_NAME" --zone="$ZONE" --project="$PROJECT" --format="value(networkInterfaces[0].networkIP)")
    
    print_success "External IP: $EXTERNAL_IP"
    print_success "Internal IP: $INTERNAL_IP"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for iPerf3 services to start (this may take 2-3 minutes)..."
    
    for i in {1..60}; do
        # Check if setup is complete by trying to SSH and check for completion marker
        if gcloud compute ssh "$SERVER_NAME" --zone="$ZONE" --project="$PROJECT" --command="test -f /tmp/setup-complete" --quiet 2>/dev/null; then
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
}

# Display final information
show_completion_info() {
    echo
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    🎉 DEPLOYMENT SUCCESSFUL! 🎉                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo
    echo "📋 Server Details:"
    echo "  • Instance Name:  $SERVER_NAME"
    echo "  • Machine Type:   $MACHINE_TYPE"
    echo "  • Project:        $PROJECT"
    echo "  • Zone:           $ZONE"
    echo "  • External IP:    $EXTERNAL_IP"
    echo "  • Preemptible:    $PREEMPTIBLE"
    echo
    echo "🧪 Quick Test Commands:"
    echo "  # Download test (3+ Gbps capable)"
    echo "  iperf3 -c $EXTERNAL_IP -p 5201 -R -t 30 -P 4"
    echo
    echo "  # Upload test"
    echo "  iperf3 -c $EXTERNAL_IP -p 5201 -t 30 -P 4"
    echo
    echo "  # UDP test"
    echo "  iperf3 -c $EXTERNAL_IP -p 5201 -u -b 3G -R -t 30"
    echo
    echo "🔧 Server Management:"
    echo "  # SSH to server"
    echo "  gcloud compute ssh $SERVER_NAME --zone=$ZONE --project=$PROJECT"
    echo
    echo "  # Check server status"
    echo "  gcloud compute ssh $SERVER_NAME --zone=$ZONE --project=$PROJECT --command='iperf3-status'"
    echo
    echo "  # Stop instance (SAVE MONEY!)"
    echo "  gcloud compute instances stop $SERVER_NAME --zone=$ZONE --project=$PROJECT"
    echo
    echo "  # Start instance"
    echo "  gcloud compute instances start $SERVER_NAME --zone=$ZONE --project=$PROJECT"
    echo
    echo "  # Delete instance (DELETE PERMANENTLY)"
    echo "  gcloud compute instances delete $SERVER_NAME --zone=$ZONE --project=$PROJECT"
    echo
    echo "💰 Cost Management:"
    if [[ "$PREEMPTIBLE" == "true" ]]; then
        echo "  • Preemptible instance: ~70% cost savings vs regular instance"
    else
        echo "  • Regular instance: Use --preemptible flag next time for 70% savings"
    fi
    echo "  • Remember to STOP the instance when not testing!"
    echo
    echo "🌐 GCP Console:"
    echo "  https://console.cloud.google.com/compute/instances?project=$PROJECT"
    echo
    print_success "Deployment completed! Server is ready for high-speed testing."
}

# Cleanup function for interrupted deployments
cleanup_on_error() {
    print_error "Deployment failed or was interrupted"
    
    if [[ -n "${SERVER_NAME:-}" && -n "${ZONE:-}" && -n "${PROJECT:-}" ]]; then
        print_status "Cleaning up instance..."
        gcloud compute instances delete "$SERVER_NAME" --zone="$ZONE" --project="$PROJECT" --quiet 2>/dev/null || true
    fi
    
    exit 1
}

# Set trap for cleanup
trap cleanup_on_error ERR INT TERM

# Main execution
main() {
    echo "iPerf3 GCP Deployment Script v${VERSION}"
    echo "==========================================="
    
    # Parse command line arguments
    parse_args "$@"
    
    # Run deployment steps
    check_prerequisites
    create_startup_script
    create_firewall_rule
    create_instance
    wait_for_instance
    wait_for_services
    show_completion_info
}

# Run main function with all arguments
main "$@"
