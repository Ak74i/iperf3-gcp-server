# iPerf3 Multi-Cloud High-Speed Test Server

iPerf3 network testing server deployment for **Google Cloud Platform** and **Amazon Web Services**. Optimized for high-throughput testing with 3+ Gbps capability.

## Quick Start (Choose Your Method) ##

| Method                        | Best For          | Files to Use                       |
|-------------------------------|-------------------|------------------------------------|
| **One-Click Scripts**         | Quick testing     | `deploy-gcp.sh` or `deploy-aws.sh` |
| **Terraform (Unified)**       | Professional use  | `terraform-unified/` directory     |
| **Terraform (AWS-specific)**  | AWS-only projects | `terraform-aws/` directory         |

##  Repository Structure ##

```
iperf3-multicloud-server/
├── 📄 README.md                     # This file - main overview
├── 📄 GUIDE-GCP.md                  # Google Cloud Platform setup guide
├── 📄 GUIDE-AWS.md                  # Amazon Web Services setup guide
│
├── 🚀 deploy-gcp.sh                 # One-click GCP deployment script
├── 🚀 deploy-aws.sh                 # One-click AWS deployment script
│
├── 📁 terraform-unified/            # Supports BOTH GCP and AWS
│   ├── main.tf                      # Multi-cloud configuration
│   ├── variables.tf                 # All variables (GCP + AWS)
│   ├── outputs.tf                   # Unified outputs
│   ├── terraform.tfvars.example     # Configuration examples
│   ├── TERRAFORM-README.md          # Terraform usage guide
│   └── scripts/
│       ├── gcp-startup.sh
│       └── aws-user-data.sh
│
├── 📁 terraform-aws/                # AWS-only Terraform
│   ├── main.tf                      # AWS-specific configuration
│   ├── variables.tf                 # AWS variables only
│   ├── outputs.tf                   # AWS outputs
│   ├── terraform.tfvars.example     # AWS configuration examples
│   ├── AWS-TERRAFORM-README.md      # AWS Terraform guide
│   └── user-data.sh
│
└── 📁 docs/                         # Professional documentation
    ├── iPerf3-Complete-Guide.docx
    ├── iPerf3-Complete-Guide.html
    └── iPerf3-Complete-Guide.txt
```

##  Usage Instructions ##

### For Google Cloud Platform
1. Read: `GUIDE-GCP.md`
2. Use: `deploy-gcp.sh` OR `terraform-unified/`

### For Amazon Web Services  
1. Read: `GUIDE-AWS.md`
2. Use: `deploy-aws.sh` OR `terraform-unified/` OR `terraform-aws/`

### For Both Clouds (Multi-Cloud)
1. Use: `terraform-unified/` directory
2. Read: `terraform-unified/TERRAFORM-README.md`

## Quick Commands ##

### One-Click Deployment
```bash
# Google Cloud
./deploy-gcp.sh --project my-project --region europe-west2

# Amazon Web Services
./deploy-aws.sh --region eu-west-2 --key-name my-key
```

### Terraform Deployment (Multi-Cloud)
```bash
cd terraform-unified/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to choose cloud provider
terraform init && terraform apply
```

## 📊 Cloud Provider Comparison

| Feature                  | Google Cloud              | Amazon Web Services |
|--------------------------|---------------------------|---------------------|
| **Max Performance**      | Up to 10 Gbps             | Up to 25 Gbps       |
| **Recommended Instance** | n1-standard-4             | c5n.xlarge          |
| **Hourly Cost**          | ~$0.19                    | ~$0.22              |
| **Spot Savings**         | ~70%                      | ~60-70%             |
| **Best For**             | Balanced cost/performance | Maximum performance |

## 💰 Cost Warning

⚠️ **IMPORTANT**: Cloud instances cost money! Always stop instances when not testing to avoid charges.

## 🤝 Support

- **Issues**: Create GitHub issue
- **Documentation**: See `GUIDE-GCP.md` or `GUIDE-AWS.md`
- **Terraform Help**: See `terraform-unified/TERRAFORM-README.md`

---

**Choose your cloud, follow the guide, deploy, and test!**
