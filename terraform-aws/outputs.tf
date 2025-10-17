# Terraform Outputs for iPerf3 AWS Deployment

# Instance Information
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id
}

output "instance_type" {
  description = "EC2 instance type"
  value       = var.instance_type
}

output "instance_state" {
  description = "Current state of the EC2 instance"
  value       = var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].state : aws_instance.iperf_server[0].instance_state
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = data.aws_ami.ubuntu.id
}

# Network Information
output "public_ip" {
  description = "Public IP address of the server"
  value       = var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)
}

output "private_ip" {
  description = "Private IP address of the server"
  value       = var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].private_ip : aws_instance.iperf_server[0].private_ip
}

output "elastic_ip" {
  description = "Elastic IP address (if enabled)"
  value       = var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : "Not allocated"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = var.create_vpc ? aws_vpc.iperf_vpc[0].id : data.aws_vpc.existing[0].id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = var.create_vpc ? aws_subnet.iperf_public_subnet[0].id : data.aws_subnet.existing[0].id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.iperf_sg.id
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].availability_zone : aws_instance.iperf_server[0].availability_zone
}

# iPerf3 Configuration
output "iperf3_ports" {
  description = "List of iPerf3 server ports"
  value       = var.iperf_ports
}

output "iperf3_test_commands" {
  description = "Quick test commands for iPerf3"
  value = {
    download_test = "iperf3 -c ${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)} -p 5201 -R -t 30 -P 4"
    upload_test   = "iperf3 -c ${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)} -p 5201 -t 30 -P 4"
    udp_test      = "iperf3 -c ${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)} -p 5201 -u -b 3G -R -t 30"
  }
}

# SSH and Management
output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh ubuntu@${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)}"
  sensitive   = false
}

output "ssh_key_name" {
  description = "Name of the SSH key pair used"
  value       = var.key_name
}

# Cost Information
output "instance_pricing" {
  description = "Instance pricing information"
  value = {
    instance_type     = var.instance_type
    estimated_hourly  = lookup(local.estimated_hourly_cost, var.instance_type, 0.20)
    estimated_monthly = lookup(local.estimated_hourly_cost, var.instance_type, 0.20) * 24 * 30
    spot_enabled      = var.use_spot_instance
    spot_max_price    = var.use_spot_instance ? var.spot_max_price : "N/A"
  }
}

# Management Commands
output "aws_cli_commands" {
  description = "Useful AWS CLI commands for managing the instance"
  value = {
    stop_instance      = "aws ec2 stop-instances --instance-ids ${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id} --region ${var.aws_region}"
    start_instance     = "aws ec2 start-instances --instance-ids ${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id} --region ${var.aws_region}"
    terminate_instance = "aws ec2 terminate-instances --instance-ids ${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id} --region ${var.aws_region}"
    get_instance_status = "aws ec2 describe-instances --instance-ids ${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id} --region ${var.aws_region}"
  }
}

# Monitoring Information
output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.iperf_logs.name
}

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.enable_monitoring
}

output "auto_stop_enabled" {
  description = "Whether auto-stop is enabled"
  value       = var.enable_auto_stop
}

# AWS Console Links
output "aws_console_links" {
  description = "Direct links to AWS console"
  value = {
    ec2_instance = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#Instances:instanceId=${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id}"
    security_group = "https://${var.aws_region}.console.aws.amazon.com/ec2/v2/home?region=${var.aws_region}#SecurityGroups:groupId=${aws_security_group.iperf_sg.id}"
    cloudwatch_logs = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.iperf_logs.name, "/", "%2F")}"
  }
}

# Spot Instance Information (if applicable)
output "spot_instance_info" {
  description = "Spot instance information"
  value = var.use_spot_instance ? {
    spot_request_id = aws_spot_instance_request.iperf_spot[0].id
    spot_price      = aws_spot_instance_request.iperf_spot[0].spot_price
    request_state   = aws_spot_instance_request.iperf_spot[0].state
    instance_id     = aws_spot_instance_request.iperf_spot[0].spot_instance_id
  } : null
}

# Network Performance Information
output "network_performance" {
  description = "Expected network performance based on instance type"
  value = {
    instance_type = var.instance_type
    network_performance = contains(["c5n.large"], var.instance_type) ? "Up to 10 Gbps" : 
                         contains(["c5n.xlarge", "c5n.2xlarge", "m5n.xlarge", "m5n.2xlarge"], var.instance_type) ? "Up to 25 Gbps" :
                         contains(["c5n.4xlarge", "m5n.4xlarge"], var.instance_type) ? "Up to 50 Gbps" : "Variable"
    enhanced_networking = var.enable_enhanced_networking
    optimized_for_3gbps = contains(["c5n.large", "c5n.xlarge", "c5n.2xlarge", "m5n.xlarge", "m5n.2xlarge"], var.instance_type)
  }
}

# Resource ARNs
output "resource_arns" {
  description = "ARNs of created resources"
  value = {
    instance_arn     = var.use_spot_instance ? "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_spot_instance_request.iperf_spot[0].spot_instance_id}" : "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.iperf_server[0].id}"
    security_group_arn = "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:security-group/${aws_security_group.iperf_sg.id}"
    log_group_arn    = aws_cloudwatch_log_group.iperf_logs.arn
  }
}

# Summary Information
output "deployment_summary" {
  description = "Complete deployment summary"
  value = {
    server_name       = var.server_name
    region           = var.aws_region
    instance_type    = var.instance_type
    instance_id      = var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id
    public_ip        = var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)
    iperf3_ports     = var.iperf_ports
    ssh_command      = "ssh ubuntu@${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)}"
    estimated_cost   = "${lookup(local.estimated_hourly_cost, var.instance_type, 0.20)} USD/hour"
    deployment_time  = timestamp()
  }
}

# Status Check URL (for automated monitoring)
output "health_check_url" {
  description = "Health check endpoint (requires custom implementation)"
  value       = "http://${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)}:8080/health"
}

# Formatted output for scripts
output "connection_info" {
  description = "Formatted connection information"
  value = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════╗
    ║                    🎉 DEPLOYMENT SUCCESSFUL! 🎉                 ║
    ╚════════════════════════════════════════════════════════════════╝
    
    Server Details:
      • Instance ID:  ${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id}
      • Region:       ${var.aws_region}
      • Zone:         ${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].availability_zone : aws_instance.iperf_server[0].availability_zone}
      • IP Address:   ${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)}
      • Instance Type: ${var.instance_type}
      • Ports:        ${join(", ", [for port in var.iperf_ports : "${port} (TCP & UDP)"])}
    
    Quick Test:
      iperf3 -c ${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)} -p 5201 -u -b 3G -R -t 60
    
    Management:
      SSH:    ssh ubuntu@${var.use_elastic_ip ? aws_eip.iperf_eip[0].public_ip : (var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].public_ip : aws_instance.iperf_server[0].public_ip)}
      Stop:   aws ec2 stop-instances --instance-ids ${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id} --region ${var.aws_region}
      Start:  aws ec2 start-instances --instance-ids ${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id} --region ${var.aws_region}
    
    AWS Console:
      ${var.aws_region == "us-east-1" ? "https://console.aws.amazon.com" : "https://${var.aws_region}.console.aws.amazon.com"}/ec2/v2/home?region=${var.aws_region}#Instances:instanceId=${var.use_spot_instance ? aws_spot_instance_request.iperf_spot[0].spot_instance_id : aws_instance.iperf_server[0].id}
    
    Remember to stop the instance when not testing to save costs!
    
  EOT
}
