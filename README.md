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
# Google Cloud (Updated machine type)
./deploy-gcp.sh --project my-project --region europe-west2 --machine-type n2-highcpu-8

# Amazon Web Services (Updated regions)
./deploy-aws.sh --region eu-west-2 --key-name my-key --instance-type c5n.xlarge
```

### Terraform Deployment (Multi-Cloud)
```bash
cd terraform-unified/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars to choose cloud provider
terraform init && terraform apply
```

## Cloud Provider Comparison (Updated)

| Feature                  | Google Cloud              | Amazon Web Services         |
|--------------------------|---------------------------|-----------------------------|
| **Max Performance**      | Up to 16 Gbps             | Up to 25 Gbps               |
| **Recommended Instance** | n2-highcpu-8              | c5n.xlarge                  |
| **Hourly Cost (Europe)** | ~€0.28 (~$0.30)           | ~$0.24                      |
| **Spot Savings**         | ~70%                      | ~60-70%                     |
| **Best For**             | High CPU performance      | Maximum network performance |

### Available Machine Types (Europe Compatible)

#### Google Cloud Platform:
- **n2-standard-4**: 4 vCPUs, 16GB RAM (~€0.17/hour) - Budget option
- **n2-highcpu-8**: 8 vCPUs, 8GB RAM (~€0.28/hour) - **Recommended**
- **n2-standard-8**: 8 vCPUs, 32GB RAM (~€0.35/hour) - High performance
- **e2-standard-4**: 4 vCPUs, 16GB RAM (~€0.13/hour) - Most budget

#### Amazon Web Services:
- **c5n.large**: 2 vCPUs, 5.25GB RAM (~$0.12/hour) - Budget option
- **c5n.xlarge**: 4 vCPUs, 10.5GB RAM (~$0.24/hour) - **Recommended**
- **c5n.2xlarge**: 8 vCPUs, 21GB RAM (~$0.48/hour) - Maximum performance

### Supported Regions

#### Europe:
- **GCP**: europe-west2 (London), europe-west1 (Belgium), europe-north1 (Finland - cheapest)
- **AWS**: eu-west-2 (London), eu-west-1 (Ireland), eu-north-1 (Stockholm - cheapest)

#### Australia & New Zealand:
- **GCP**: australia-southeast1 (Sydney), australia-southeast2 (Melbourne)
- **AWS**: ap-southeast-2 (Sydney), ap-southeast-4 (Melbourne), ap-southeast-6 (Auckland)

## Cost Warning

⚠️ **IMPORTANT**: Cloud instances cost money! Always stop instances when not testing to avoid charges.

## Support

- **Issues**: Create GitHub issue
- **Documentation**: See `GUIDE-GCP.md` or `GUIDE-AWS.md`
- **Terraform Help**: See `terraform-unified/TERRAFORM-README.md`

---

**Choose your cloud, follow the guide, deploy, and test!**
