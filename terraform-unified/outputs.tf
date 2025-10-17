# Terraform Outputs for Multi-Cloud iPerf3 Deployment
# Supports both Google Cloud Platform and Amazon Web Services

# ============================================================================
# GENERAL DEPLOYMENT INFORMATION
# ============================================================================

output "cloud_provider" {
  description = "Cloud provider used for deployment"
  value       = var.cloud_provider
}

output "server_name" {
  description = "Name of the iPerf3 server"
  value       = var.server_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "deployment_region" {
  description = "Deployment region"
  value       = var.cloud_provider == "gcp" ? var.gcp_region : var.aws_region
}

output "deployment_zone" {
  description = "Deployment zone/availability zone"
  value       = local.zone
}

# ============================================================================
# INSTANCE INFORMATION
# ============================================================================

output "instance_id" {
  description = "ID of the server instance"
  value       = local.instance_id
}

output "instance_type" {
  description = "Instance/machine type"
  value       = var.cloud_provider == "gcp" ? var.gcp_machine_type : var.aws_instance_type
}

output "instance_state" {
  description = "Current state of the instance"
  value = var.cloud_provider == "gcp" ? "RUNNING" : (
    var.use_preemptible_spot ? aws_spot_instance_request.iperf_spot[0].state : aws_instance.iperf_server_aws[0].instance_state
  )
}

# ============================================================================
# NETWORK INFORMATION
# ============================================================================

output "public_ip" {
  description = "Public IP address of the server"
  value       = local.public_ip
}

output "private_ip" {
  description = "Private IP address of the server"
  value       = local.private_ip
}

output "elastic_ip" {
  description = "Elastic IP address (AWS only, if enabled)"
  value       = var.cloud_provider == "aws" && var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : "Not allocated"
}

output "static_ip" {
  description = "Static IP information"
  value = var.cloud_provider == "gcp" ? "Using ephemeral IP" : (
    var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : "Using ephemeral IP"
  )
}

# ============================================================================
# IPERF3 CONFIGURATION
# ============================================================================

output "iperf3_ports" {
  description = "List of iPerf3 server ports"
  value       = var.iperf_ports
}

output "iperf3_test_commands" {
  description = "Quick test commands for iPerf3"
  value = {
    download_test_basic     = "iperf3 -c ${local.public_ip} -p 5201 -R -t 30"
    download_test_parallel  = "iperf3 -c ${local.public_ip} -p 5201 -R -t 30 -P 4"
    upload_test_basic      = "iperf3 -c ${local.public_ip} -p 5201 -t 30"
    upload_test_parallel   = "iperf3 -c ${local.public_ip} -p 5201 -t 30 -P 4"
    udp_test_1gbps         = "iperf3 -c ${local.public_ip} -p 5201 -u -b 1G -R -t 30"
    udp_test_3gbps         = "iperf3 -c ${local.public_ip} -p 5201 -u -b 3G -R -t 30"
    udp_test_max           = "iperf3 -c ${local.public_ip} -p 5201 -u -b 0 -R -t 30"
  }
}

output "multi_port_test_script" {
  description = "Script to test all ports simultaneously"
  value = <<-EOT
    #!/bin/bash
    # Test all iPerf3 instances simultaneously
    echo "Testing all ${length(var.iperf_ports)} iPerf3 instances..."
    
    # Start background tests
    for port in ${join(" ", var.iperf_ports)}; do
        echo "Starting test on port $port..."
        iperf3 -c ${local.public_ip} -p $port -t 30 -P 2 > iperf3-port-$port.log 2>&1 &
    done
    
    # Wait for all tests to complete
    wait
    
    echo "All tests completed. Results:"
    for port in ${join(" ", var.iperf_ports)}; do
        echo "=== Port $port ==="
        tail -5 iperf3-port-$port.log | grep sender
    done
  EOT
}

# ============================================================================
# SSH AND MANAGEMENT
# ============================================================================

output "ssh_command" {
  description = "SSH command to connect to the server"
  value = var.cloud_provider == "gcp" ? 
    "gcloud compute ssh ${var.server_name} --zone=${var.gcp_zone} --project=${var.gcp_project_id}" :
    "ssh ubuntu@${local.public_ip}"
}

output "ssh_key_info" {
  description = "SSH key information"
  value = var.cloud_provider == "gcp" ? 
    "Using gcloud SSH (automatic key management)" :
    "Key pair: ${var.aws_key_name}"
}

# ============================================================================
# COST INFORMATION
# ============================================================================

output "cost_estimation" {
  description = "Cost estimation for the deployment"
  value = {
    cloud_provider           = var.cloud_provider
    instance_type           = var.cloud_provider == "gcp" ? var.gcp_machine_type : var.aws_instance_type
    estimated_hourly_cost   = local.estimated_cost
    estimated_daily_cost    = local.estimated_cost * 24
    estimated_monthly_cost  = local.estimated_cost * 24 * 30
    spot_preemptible_enabled = var.use_preemptible_spot
    estimated_spot_savings  = var.use_preemptible_spot ? "${var.cloud_provider == "gcp" ? "70" : "60-70"}% cost reduction" : "Not using spot/preemptible"
    currency                = "USD"
  }
}

output "cost_optimization_tips" {
  description = "Cost optimization recommendations"
  value = [
    var.use_preemptible_spot ? "✅ Using spot/preemptible instances for cost savings" : "💡 Enable spot/preemptible instances for 60-70% savings",
    "💰 Stop the instance when not testing to avoid charges",
    "📊 Monitor usage with cloud billing dashboards",
    "⏰ Set up billing alerts to avoid unexpected costs",
    var.cloud_provider == "aws" && var.enable_auto_stop ? "✅ Auto-stop enabled when idle" : "💡 Enable auto-stop to prevent idle charges"
  ]
}

# ============================================================================
# PERFORMANCE INFORMATION
# ============================================================================

output "performance_specifications" {
  description = "Expected performance specifications"
  value = {
    instance_type           = var.cloud_provider == "gcp" ? var.gcp_machine_type : var.aws_instance_type
    network_performance     = local.expected_network_performance
    iperf3_instances        = length(var.iperf_ports)
    optimized_for_3gbps     = contains(["n1-standard-4", "n2-standard-4", "c2-standard-4"], var.gcp_machine_type) || contains(["c5n.large", "c5n.xlarge", "c5n.2xlarge", "m5n.xlarge"], var.aws_instance_type)
    enhanced_networking     = var.enable_enhanced_networking
    expected_tcp_throughput = var.cloud_provider == "gcp" ? "3-8 Gbps" : "5-15 Gbps"
    expected_udp_throughput = var.cloud_provider == "gcp" ? "Up to 10 Gbps" : "Up to 25 Gbps"
  }
}

# ============================================================================
# PROVIDER-SPECIFIC MANAGEMENT COMMANDS
# ============================================================================

output "cloud_management_commands" {
  description = "Cloud-specific management commands"
  value = var.cloud_provider == "gcp" ? {
    provider = "Google Cloud Platform"
    stop_instance = "gcloud compute instances stop ${var.server_name} --zone=${var.gcp_zone} --project=${var.gcp_project_id}"
    start_instance = "gcloud compute instances start ${var.server_name} --zone=${var.gcp_zone} --project=${var.gcp_project_id}"
    delete_instance = "gcloud compute instances delete ${var.server_name} --zone=${var.gcp_zone} --project=${var.gcp_project_id}"
    get_status = "gcloud compute instances describe ${var.server_name} --zone=${var.gcp_zone} --project=${var.gcp_project_id} --format='value(status)'"
    view_logs = "gcloud logging read 'resource.type=\"gce_instance\" AND resource.labels.instance_name=\"${var.server_name}\"' --project=${var.gcp_project_id} --limit=50"
  } : {
    provider = "Amazon Web Services"
    stop_instance = "aws ec2 stop-instances --instance-ids ${local.instance_id} --region ${var.aws_region}"
    start_instance = "aws ec2 start-instances --instance-ids ${local.instance_id} --region ${var.aws_region}"
    terminate_instance = "aws ec2 terminate-instances --instance-ids ${local.instance_id} --region ${var.aws_region}"
    get_status = "aws ec2 describe-instances --instance-ids ${local.instance_id} --region ${var.aws_region} --query 'Reservations[0].Instances[0].State.Name' --output text"
    view_logs = var.enable_monitoring ? "aws logs tail /aws/ec2/${var.server_name} --region ${var.aws_region} --follow" : "CloudWatch logs not enabled"
  }
}

# ============================================================================
# CONSOLE/DASHBOARD LINKS
# ============================================================================

output "cloud_console_links" {
  description = "Direct links to cloud console"
  value = var.cloud_provider == "gcp" ? {
    instance = "https://console.cloud.google.com/compute/instances?project=${var.gcp_project_id}"
    monitoring = "https://console.cloud.google.com/monitoring?project=${var.gcp_project_id}"
    logging = "https://console.cloud.google.com/logs?project=${var.gcp_project_id}"
    billing = "https://console.cloud.google.com/billing?project=${var.gcp_project_id}"
  } : {
    instance = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#Instances:instanceId=${local.instance_id}"
    cloudwatch = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}"
    cloudwatch_logs = var.enable_monitoring ? "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.iperf_logs[0].name, "/", "%2F")}" : "CloudWatch logs not enabled"
    billing = "https://console.aws.amazon.com/billing/"
  }
}

# ============================================================================
# SECURITY INFORMATION
# ============================================================================

output "security_configuration" {
  description = "Security configuration details"
  value = {
    ssh_access_from = var.allow_ssh_from_anywhere ? "0.0.0.0/0 (WARNING: Open to internet)" : join(", ", var.ssh_cidr_blocks)
    iperf3_ports_open = "5201-5205 (TCP & UDP) - Open to internet"
    health_check_port = "8080 (HTTP) - Open to internet"
    https_enabled = false
    firewall_rules = var.cloud_provider == "gcp" ? "GCP firewall rules applied" : "AWS security group configured"
    encryption_at_rest = var.cloud_provider == "gcp" ? "Enabled by default" : "Enabled (EBS encryption)"
  }
}

# ============================================================================
# MONITORING AND HEALTH
# ============================================================================

output "monitoring_configuration" {
  description = "Monitoring and health check configuration"
  value = {
    cloud_monitoring_enabled = var.enable_monitoring
    health_check_url = "http://${local.public_ip}:8080/health"
    log_retention_days = var.log_retention_days
    auto_stop_enabled = var.enable_auto_stop
    monitoring_dashboard = var.cloud_provider == "gcp" ? "Google Cloud Monitoring" : "AWS CloudWatch"
  }
}

# ============================================================================
# PROVIDER-SPECIFIC OUTPUTS
# ============================================================================

# GCP-specific outputs
output "gcp_specific_info" {
  description = "GCP-specific information (only when using GCP)"
  value = var.cloud_provider == "gcp" ? {
    project_id = var.gcp_project_id
    region = var.gcp_region
    zone = var.gcp_zone
    machine_type = var.gcp_machine_type
    preemptible = var.use_preemptible_spot
    instance_name = google_compute_instance.iperf_server_gcp[0].name
    self_link = google_compute_instance.iperf_server_gcp[0].self_link
    network_interface = google_compute_instance.iperf_server_gcp[0].network_interface[0].name
  } : null
}

# AWS-specific outputs
output "aws_specific_info" {
  description = "AWS-specific information (only when using AWS)"
  value = var.cloud_provider == "aws" ? {
    region = var.aws_region
    instance_type = var.aws_instance_type
    key_name = var.aws_key_name
    vpc_id = var.aws_create_vpc ? aws_vpc.iperf_vpc[0].id : var.aws_existing_vpc_id
    subnet_id = var.aws_create_vpc ? aws_subnet.iperf_public_subnet[0].id : var.aws_existing_subnet_id
    security_group_id = aws_security_group.iperf_sg[0].id
    spot_instance = var.use_preemptible_spot
    elastic_ip_allocated = var.use_elastic_ip
    ami_id = data.aws_ami.ubuntu[0].id
  } : null
}

# ============================================================================
# COMPLETE DEPLOYMENT SUMMARY
# ============================================================================

output "deployment_summary" {
  description = "Complete deployment summary"
  value = {
    # Basic info
    cloud_provider = var.cloud_provider
    server_name = var.server_name
    instance_id = local.instance_id
    instance_type = var.cloud_provider == "gcp" ? var.gcp_machine_type : var.aws_instance_type
    
    # Network
    public_ip = local.public_ip
    private_ip = local.private_ip
    region = var.cloud_provider == "gcp" ? var.gcp_region : var.aws_region
    zone = local.zone
    
    # iPerf3
    iperf3_ports = var.iperf_ports
    health_check_url = "http://${local.public_ip}:8080/health"
    
    # Management
    ssh_command = var.cloud_provider == "gcp" ? 
      "gcloud compute ssh ${var.server_name} --zone=${var.gcp_zone} --project=${var.gcp_project_id}" :
      "ssh ubuntu@${local.public_ip}"
    
    # Cost
    estimated_hourly_cost = "${local.estimated_cost} USD"
    spot_preemptible_enabled = var.use_preemptible_spot
    
    # Performance
    expected_network_performance = local.expected_network_performance
    
    # Deployment time
    deployment_timestamp = timestamp()
  }
}

# ============================================================================
# QUICK START INFORMATION
# ============================================================================

output "quick_start_info" {
  description = "Quick start information for immediate testing"
  value = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════╗
    ║               🎉 MULTI-CLOUD DEPLOYMENT SUCCESSFUL! 🎉          ║
    ╚════════════════════════════════════════════════════════════════╝
    
    Cloud Provider: ${upper(var.cloud_provider)}
    Server Details:
      • Name:          ${var.server_name}
      • Instance ID:   ${local.instance_id}
      • Instance Type: ${var.cloud_provider == "gcp" ? var.gcp_machine_type : var.aws_instance_type}
      • Region:        ${var.cloud_provider == "gcp" ? var.gcp_region : var.aws_region}
      • Zone:          ${local.zone}
      • Public IP:     ${local.public_ip}
      • Network Perf:  ${local.expected_network_performance}
    
    🧪 Quick Performance Test:
      iperf3 -c ${local.public_ip} -p 5201 -R -t 30 -P 4
    
    🔧 Server Management:
      SSH: ${var.cloud_provider == "gcp" ? "gcloud compute ssh ${var.server_name} --zone=${var.gcp_zone}" : "ssh ubuntu@${local.public_ip}"}
      Status: ${var.cloud_provider == "gcp" ? "gcloud compute instances describe ${var.server_name} --zone=${var.gcp_zone}" : "aws ec2 describe-instances --instance-ids ${local.instance_id}"}
    
    💰 Cost Information:
      • Estimated: $${local.estimated_cost}/hour (~$${local.estimated_cost * 24 * 30}/month)
      • Spot/Preemptible: ${var.use_preemptible_spot ? "✅ Enabled" : "❌ Disabled"} 
      • Remember to stop when not testing!
    
    🌐 Console Access:
      ${var.cloud_provider == "gcp" ? "https://console.cloud.google.com/compute/instances?project=${var.gcp_project_id}" : "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#Instances:instanceId=${local.instance_id}"}
    
    ⚡ Multi-Port Test (all ${length(var.iperf_ports)} instances):
      for port in ${join(" ", var.iperf_ports)}; do iperf3 -c ${local.public_ip} -p $$port -t 30 & done; wait
    
  EOT
}

# ============================================================================
# TROUBLESHOOTING INFORMATION
# ============================================================================

output "troubleshooting_info" {
  description = "Common troubleshooting commands and information"
  value = {
    check_instance_status = var.cloud_provider == "gcp" ? 
      "gcloud compute instances describe ${var.server_name} --zone=${var.gcp_zone} --format='value(status)'" :
      "aws ec2 describe-instances --instance-ids ${local.instance_id} --query 'Reservations[0].Instances[0].State.Name' --output text"
    
    check_firewall_rules = var.cloud_provider == "gcp" ? 
      "gcloud compute firewall-rules list --filter='name~iperf3'" :
      "aws ec2 describe-security-groups --group-ids ${aws_security_group.iperf_sg[0].id}"
    
    view_startup_logs = var.cloud_provider == "gcp" ? 
      "gcloud compute instances get-serial-port-output ${var.server_name} --zone=${var.gcp_zone}" :
      "aws ec2 get-console-output --instance-id ${local.instance_id}"
    
    ssh_troubleshooting = [
      "Ensure your SSH key is properly configured",
      var.cloud_provider == "gcp" ? "Use 'gcloud auth login' to authenticate" : "Verify AWS key pair exists in the region",
      "Check that firewall/security group allows SSH from your IP",
      "Wait 2-3 minutes after deployment for services to start"
    ]
    
    performance_troubleshooting = [
      "Test from multiple geographic locations",
      "Use parallel connections: add -P 4 to iperf3 commands", 
      "Try different ports: 5201, 5202, 5203, 5204, 5205",
      "Check client-side network limitations",
      "Verify instance type supports expected throughput"
    ]
  }
}
