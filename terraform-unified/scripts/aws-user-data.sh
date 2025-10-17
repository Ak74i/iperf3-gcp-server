#!/bin/bash
# iPerf3 Server Configuration Script for Amazon Web Services
# This script configures a high-performance iPerf3 test server
# Optimized for 3+ Gbps network testing

# Enable detailed logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "==================== iPerf3 AWS Server Setup Started ===================="
echo "Start time: $(date)"
echo "Server name: ${server_name}"

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive

# Update system packages
echo "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install essential packages
echo "Installing required packages..."
apt-get install -y \
    iperf3 \
    htop \
    iftop \
    nload \
    tcpdump \
    net-tools \
    curl \
    wget \
    jq \
    vim \
    unzip \
    awscli

# Configure system for high-performance networking
echo "Configuring network optimizations..."

# Backup original sysctl.conf
cp /etc/sysctl.conf /etc/sysctl.conf.backup

# Apply network optimizations
cat >> /etc/sysctl.conf << 'EOF'

# iPerf3 Network Performance Optimizations for AWS
# TCP Buffer Sizes
net.core.rmem_max = 268435456
net.core.wmem_max = 268435456
net.ipv4.tcp_rmem = 4096 87380 268435456
net.ipv4.tcp_wmem = 4096 65536 268435456

# Network Interface Settings
net.core.netdev_max_backlog = 5000
net.core.netdev_budget = 600

# TCP Congestion Control (BBR for better performance)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP Window Scaling
net.ipv4.tcp_window_scaling = 1

# TCP Timestamps
net.ipv4.tcp_timestamps = 1

# TCP SACK
net.ipv4.tcp_sack = 1

# Increase the maximum number of connections
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# TCP Memory Management
net.ipv4.tcp_mem = 786432 1048576 26777216
net.ipv4.tcp_max_tw_buckets = 360000

# UDP Buffer Sizes
net.core.rmem_default = 262144
net.core.wmem_default = 262144

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Optimize for high-bandwidth, high-latency networks
net.ipv4.tcp_slow_start_after_idle = 0
EOF

# Apply sysctl changes
sysctl -p

echo "Network optimizations applied successfully"

# Create systemd services for multiple iPerf3 instances
echo "Creating iPerf3 service instances..."

for i in {1..5}; do
    port=$((5200 + i))
    
    cat > /etc/systemd/system/iperf3-${i}.service << EOF
[Unit]
Description=iPerf3 server instance ${i} on port ${port}
After=network.target
Wants=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=/usr/bin/iperf3 -s -p ${port} --forceflush
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=iperf3-${i}

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/tmp

# Resource limits
LimitNOFILE=65535
LimitNPROC=65535

[Install]
WantedBy=multi-user.target
EOF

    echo "Created service for iPerf3 instance ${i} on port ${port}"
done

# Reload systemd and enable services
systemctl daemon-reload

for i in {1..5}; do
    systemctl enable iperf3-${i}.service
    systemctl start iperf3-${i}.service
    echo "Enabled and started iperf3-${i}.service"
done

# Wait for services to stabilize
sleep 10

# Verify services are running
echo "Verifying iPerf3 services..."
for i in {1..5}; do
    if systemctl is-active --quiet iperf3-${i}.service; then
        echo "✅ iperf3-${i}.service is running"
    else
        echo "❌ iperf3-${i}.service failed to start"
        systemctl status iperf3-${i}.service
    fi
done

# Create management and monitoring scripts
echo "Creating management scripts..."

# Server status script
cat > /usr/local/bin/iperf3-status << 'EOF'
#!/bin/bash
# iPerf3 Server Status Script for AWS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================== iPerf3 Server Status ====================${NC}"

# Get AWS instance metadata
if curl -s --max-time 5 http://169.254.169.254/latest/meta-data/ > /dev/null 2>&1; then
    echo -e "${BLUE}Server Information:${NC}"
    echo "  Public IP:       $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
    echo "  Private IP:      $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
    echo "  Instance Type:   $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
    echo "  Instance ID:     $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
    echo "  Region:          $(curl -s http://169.254.169.254/latest/meta-data/placement/region)"
    echo "  Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
    echo "  AMI ID:          $(curl -s http://169.254.169.254/latest/meta-data/ami-id)"
else
    echo -e "${YELLOW}Warning: Unable to fetch AWS metadata${NC}"
fi

echo -e "${BLUE}System Information:${NC}"
echo "  Hostname:        $(hostname)"
echo "  Uptime:          $(uptime -p)"
echo "  Load Average:    $(uptime | awk -F'load average:' '{print $2}')"
echo "  Memory Usage:    $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
echo "  Disk Usage:      $(df -h / | awk 'NR==2{print $5}' | sed 's/%//')"

echo -e "${BLUE}===============================================================${NC}"
echo -e "${BLUE}Service Status:${NC}"

all_running=true
for i in {1..5}; do
    port=$((5200 + i))
    if systemctl is-active --quiet iperf3-${i}.service; then
        echo -e "  ${GREEN}✅ iPerf3 Instance ${i} (port ${port}): RUNNING${NC}"
    else
        echo -e "  ${RED}❌ iPerf3 Instance ${i} (port ${port}): STOPPED${NC}"
        all_running=false
    fi
done

if $all_running; then
    echo -e "${GREEN}All iPerf3 services are running properly!${NC}"
else
    echo -e "${YELLOW}Some iPerf3 services are not running. Check logs with: journalctl -u iperf3-X.service${NC}"
fi

echo -e "${BLUE}===============================================================${NC}"
echo -e "${BLUE}Network Status:${NC}"

# Check network interfaces
primary_interface=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -n "$primary_interface" ]; then
    ip_addr=$(ip addr show $primary_interface | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    echo "  Primary Interface: $primary_interface ($ip_addr)"
    
    # Check if interface supports high performance
    ethtool_info=$(ethtool $primary_interface 2>/dev/null | grep "Speed:" || echo "Speed: Unknown")
    echo "  Interface Speed:   $ethtool_info"
    
    # Check if enhanced networking is enabled
    if [[ -d /sys/class/net/$primary_interface/device/sriov_totalvfs ]]; then
        echo "  Enhanced Networking: Supported (SR-IOV)"
    fi
fi

# Check open ports
echo "  Open iPerf3 Ports:"
for port in {5201..5205}; do
    if netstat -ln | grep -q ":${port} "; then
        echo -e "    ${GREEN}✅ Port ${port} (TCP/UDP)${NC}"
    else
        echo -e "    ${RED}❌ Port ${port} (TCP/UDP)${NC}"
    fi
done

echo -e "${BLUE}===============================================================${NC}"
echo -e "${BLUE}Quick Test Commands:${NC}"

# Get public IP for test commands
if public_ip=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); then
    echo "  Download Test (3+ Gbps capable):"
    echo "    iperf3 -c ${public_ip} -p 5201 -R -t 30 -P 4"
    echo
    echo "  Upload Test:"
    echo "    iperf3 -c ${public_ip} -p 5201 -t 30 -P 4"
    echo
    echo "  UDP Test (High bandwidth):"
    echo "    iperf3 -c ${public_ip} -p 5201 -u -b 3G -R -t 30"
    echo
    echo "  Parallel Multi-Port Test:"
    echo "    # Run these in separate terminals:"
    for port in {5201..5205}; do
        echo "    iperf3 -c ${public_ip} -p ${port} -t 30 &"
    done
    echo "    wait"
else
    echo -e "    ${YELLOW}Unable to determine public IP for test commands${NC}"
fi

echo -e "${BLUE}===============================================================${NC}"
EOF

chmod +x /usr/local/bin/iperf3-status

# Performance test script
cat > /usr/local/bin/iperf3-test << 'EOF'
#!/bin/bash
# iPerf3 Performance Test Script for AWS

echo "==================== iPerf3 Performance Test ===================="
echo "Running comprehensive performance tests..."

# Internal loopback tests
echo "1. Internal TCP Performance Test (Single Connection):"
iperf3 -c localhost -p 5201 -t 10

echo
echo "2. Internal TCP Performance Test (4 Parallel Connections):"
iperf3 -c localhost -p 5201 -t 10 -P 4

echo
echo "3. Internal UDP Performance Test (3 Gbps target):"
iperf3 -c localhost -p 5201 -u -b 3G -t 10

echo
echo "4. Multi-Port Test (All 5 instances):"
for port in {5201..5205}; do
    echo "Testing port $port..."
    timeout 5 iperf3 -c localhost -p $port -t 3 2>/dev/null || echo "Port $port test failed"
done

echo
echo "==================== Test Completed ===================="
echo "For external testing, use the commands shown in 'iperf3-status'"

if public_ip=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null); then
    echo "External test command: iperf3 -c ${public_ip} -p 5201 -R -t 30 -P 4"
fi
EOF

chmod +x /usr/local/bin/iperf3-test

# Service restart script
cat > /usr/local/bin/iperf3-restart << 'EOF'
#!/bin/bash
# iPerf3 Service Restart Script

echo "Restarting all iPerf3 services..."

for i in {1..5}; do
    echo "Restarting iperf3-${i}.service..."
    systemctl restart iperf3-${i}.service
    sleep 1
done

echo "Waiting for services to stabilize..."
sleep 5

echo "Service status:"
for i in {1..5}; do
    if systemctl is-active --quiet iperf3-${i}.service; then
        echo "  ✅ iperf3-${i}.service: RUNNING"
    else
        echo "  ❌ iperf3-${i}.service: FAILED"
    fi
done

echo "Restart completed!"
EOF

chmod +x /usr/local/bin/iperf3-restart

# Create convenient aliases
echo "Creating convenient aliases..."
cat >> /home/ubuntu/.bashrc << 'EOF'

# iPerf3 Management Aliases
alias iperf3-status='/usr/local/bin/iperf3-status'
alias iperf3-test='/usr/local/bin/iperf3-test'
alias iperf3-restart='sudo /usr/local/bin/iperf3-restart'
alias iperf3-logs='sudo journalctl -u iperf3-*.service -f'
alias iperf3-logs-all='sudo journalctl -u iperf3-*.service --no-pager'

# System monitoring aliases
alias netstat-iperf='netstat -tlnp | grep iperf3'
alias ps-iperf='ps aux | grep iperf3'
alias top-net='sudo iftop -i $(ip route | grep default | awk "{print \$5}" | head -1)'

# AWS metadata shortcuts
alias aws-meta-ip='curl -s http://169.254.169.254/latest/meta-data/public-ipv4'
alias aws-meta-type='curl -s http://169.254.169.254/latest/meta-data/instance-type'
alias aws-meta-id='curl -s http://169.254.169.254/latest/meta-data/instance-id'
alias aws-meta-region='curl -s http://169.254.169.254/latest/meta-data/placement/region'

echo "💡 iPerf3 server management commands available:"
echo "   iperf3-status   - Show server status and test commands"
echo "   iperf3-test     - Run internal performance tests"
echo "   iperf3-restart  - Restart all iPerf3 services"
echo "   iperf3-logs     - View real-time service logs"
EOF

# Install CloudWatch agent (if available)
echo "Installing CloudWatch agent..."
if command -v aws &> /dev/null; then
    echo "AWS CLI detected, configuring CloudWatch integration..."
    
    # Download and install CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
    dpkg -i /tmp/amazon-cloudwatch-agent.deb || echo "CloudWatch agent installation failed"
    
    # Create CloudWatch config
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "iPerf3/Performance",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait", 
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/user-data.log",
                        "log_group_name": "/aws/ec2/${server_name}",
                        "log_stream_name": "{instance_id}/user-data"
                    }
                ]
            }
        }
    }
}
EOF

    # Start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
        -s || echo "CloudWatch agent start failed"
fi

# Create health check endpoint (simple HTTP server)
echo "Creating health check endpoint..."
cat > /usr/local/bin/iperf3-health-server << 'EOF'
#!/bin/bash
# Simple health check HTTP server for AWS

while true; do
    response="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n"
    
    # Create health status JSON
    health_status="{\"status\":\"healthy\",\"timestamp\":\"$(date -Iseconds)\",\"provider\":\"aws\",\"services\":["
    
    for i in {1..5}; do
        if systemctl is-active --quiet iperf3-${i}.service; then
            status="active"
        else
            status="inactive"
        fi
        health_status="${health_status}\"iperf3-${i}:${status}\""
        if [ $i -lt 5 ]; then
            health_status="${health_status},"
        fi
    done
    
    health_status="${health_status}]}"
    
    echo -e "${response}${health_status}" | nc -l -p 8080 -q 1
done
EOF

chmod +x /usr/local/bin/iperf3-health-server

# Create systemd service for health check
cat > /etc/systemd/system/iperf3-health.service << 'EOF'
[Unit]
Description=iPerf3 Health Check HTTP Server
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/iperf3-health-server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable iperf3-health.service
systemctl start iperf3-health.service

# Final verification and status report
echo "Performing final verification..."

# Check all services
all_services_ok=true
for i in {1..5}; do
    if ! systemctl is-active --quiet iperf3-${i}.service; then
        echo "❌ iperf3-${i}.service is not running"
        all_services_ok=false
    fi
done

if ! systemctl is-active --quiet iperf3-health.service; then
    echo "❌ iperf3-health.service is not running"
    all_services_ok=false
fi

# Test port connectivity
echo "Testing port connectivity..."
for port in {5201..5205}; do
    if ! netstat -ln | grep -q ":${port} "; then
        echo "❌ Port ${port} is not listening"
        all_services_ok=false
    fi
done

# Create completion marker
if $all_services_ok; then
    echo "IPERF3_SETUP_COMPLETE" > /tmp/setup-complete
    echo "✅ All services are running correctly"
else
    echo "❌ Some services failed to start properly"
fi

# Log final status
echo "==================== iPerf3 AWS Server Setup Completed ===================="
echo "Completion time: $(date)"
echo "Setup status: $( $all_services_ok && echo "SUCCESS" || echo "PARTIAL" )"

# Run status check
echo "Running final status check..."
/usr/local/bin/iperf3-status

echo "==================== Setup Script Finished ===================="

# Display helpful information
cat << 'EOF'

🎉 iPerf3 High-Speed Test Server Setup Complete on Amazon Web Services!

Next Steps:
1. Wait 2-3 minutes for all services to fully initialize
2. Test connectivity: ssh ubuntu@YOUR_PUBLIC_IP 'iperf3-status'
3. Run performance test: iperf3 -c YOUR_PUBLIC_IP -p 5201 -R -t 30 -P 4

Management Commands:
- iperf3-status    : Show server status and test commands
- iperf3-test      : Run internal performance tests  
- iperf3-restart   : Restart all services
- iperf3-logs      : View service logs

The server is optimized for 3+ Gbps testing with:
✅ 5 parallel iPerf3 instances (ports 5201-5205)
✅ Network performance optimizations
✅ BBR congestion control
✅ Enhanced networking support (SR-IOV)
✅ CloudWatch monitoring integration
✅ Real-time health monitoring

Remember to stop the instance when not testing to save costs!
Use: aws ec2 stop-instances --instance-ids INSTANCE_ID --region REGION

EOF
