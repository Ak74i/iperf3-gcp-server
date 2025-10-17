# iPerf3 High-Speed Test Server for Google Cloud Platform (GCP)

[![GCP](https://img.shields.io/badge/GCP-Ready-4285F4?logo=google-cloud)](https://cloud.google.com)
[![iPerf3](https://img.shields.io/badge/iPerf3-Optimized-success)](https://iperf.fr/)

Complete guide for deploying an iPerf3 high-speed test server (3+ Gbps capable) on Google Cloud Platform.

##  Quick Start ##

**One-command deployment:**
```bash
./deploy-gcp.sh --project my-gcp-project --region europe-west2
```

##  Prerequisites ##

### Required Tools
- **gcloud CLI** - [Installation Guide](https://cloud.google.com/sdk/docs/install)
- **Terraform** (optional) - [Download](https://terraform.io/downloads)

### GCP Account Setup ##
1. **Create GCP Account** - [Sign up here](https://cloud.google.com/free)
2. **Create Project** - [GCP Console](https://console.cloud.google.com/)
3. **Enable APIs:**
   ```bash
   gcloud services enable compute.googleapis.com
   ```
4. **Authenticate:**
   ```bash
   gcloud auth login
   gcloud config set project YOUR-PROJECT-ID
   ```

##  Deployment Options ##

### Option 1: One-Click Script (Recommended for Testing)

```bash
# Basic deployment
./deploy-gcp.sh --project my-project --region europe-west2

# Custom deployment
./deploy-gcp.sh --project my-project --region europe-west2 --machine-type n1-standard-4 --preemptible
```

### Option 2: Terraform (Recommended for Production)

```bash
# Use unified terraform (supports both GCP and AWS)
cd terraform-unified/
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars:
cloud_provider = "gcp"
gcp_project_id = "my-gcp-project"
gcp_region = "europe-west2"
gcp_zone = "europe-west2-a"

# Deploy
terraform init
terraform plan
terraform apply
```

## ⚙️ Instance Types & Performance

### Recommended Machine Types for 3+ Gbps (pricing is in USD$)

| Machine Type      | vCPUs | RAM   | Network Performance | Cost/Hour* |
|-------------------|-------|-------|---------------------|------------|
| **n1-standard-2** | 2     | 7.5GB | Up to 10 Gbps       | ~$0.10     |
| **n1-standard-4** | 4     | 15GB  | Up to 10 Gbps       | ~$0.19     |
| **n2-standard-4** | 4     | 16GB  | Up to 10 Gbps       | ~$0.19     |
| **c2-standard-4** | 4     | 16GB  | Up to 10 Gbps       | ~$0.20     |

*Pricing for europe-west2 region

## 🧪 Testing Your Server

### Get Server Information

```bash
# SSH to your instance
gcloud compute ssh iperf3-server --zone=europe-west2-a --project=YOUR-PROJECT

# Check server status
iperf3-status
```

### Performance Tests

**Get your server's external IP:**
```bash
EXTERNAL_IP=$(gcloud compute instances describe iperf3-server --zone=europe-west2-a --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
```

**Download Speed Test (3+ Gbps capable):**
```bash
iperf3 -c $EXTERNAL_IP -p 5201 -R -t 30 -P 4
```

**Upload Speed Test:**
```bash
iperf3 -c $EXTERNAL_IP -p 5201 -t 30 -P 4
```

**UDP Test (High bandwidth):**
```bash
iperf3 -c $EXTERNAL_IP -p 5201 -u -b 3G -R -t 30
```

**Multi-Port Test:**
```bash
for port in {5201..5205}; do
    iperf3 -c $EXTERNAL_IP -p $port -t 30 &
done
wait
```

## 💰 Cost Management

### Pricing (europe-west2) (pricing is in USD$)

| Machine Type      | On-Demand/Hour | Preemptible/Hour | Monthly (24/7) |
|-------------------|----------------|------------------|----------------|
| **n1-standard-2** | $0.095         | $0.020           | ~$68           |
| **n1-standard-4** | $0.190         | $0.040           | ~$137          |
| **n2-standard-4** | $0.194         | $0.041           | ~$140          |

### Cost Optimization

**1. Use Preemptible Instances (70% savings):**
```bash
./deploy-gcp.sh --project my-project --region europe-west2 --preemptible
```

**2. Stop instance when not testing:**
```bash
gcloud compute instances stop iperf3-server --zone=europe-west2-a
```

**3. Start when needed:**
```bash
gcloud compute instances start iperf3-server --zone=europe-west2-a
```

**4. Delete when finished:**
```bash
gcloud compute instances delete iperf3-server --zone=europe-west2-a
```

## ⚠️ Important Cost Warning

> **💸 COST ALERT**: Running 24/7 can cost $70-140+ per month! Always stop instances when not testing.

## 🔧 Manual Setup (Advanced)

### 1. Create Firewall Rules

```bash
gcloud compute firewall-rules create iperf3-server-firewall \
    --allow tcp:22,tcp:5201-5205,udp:5201-5205 \
    --source-ranges 0.0.0.0/0 \
    --description "iPerf3 test server firewall rule"
```

### 2. Create Instance

```bash
gcloud compute instances create iperf3-server \
    --zone=europe-west2-a \
    --machine-type=n1-standard-4 \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-standard \
    --tags=iperf3-server \
    --metadata-from-file startup-script=scripts/gcp-startup.sh
```

### 3. Make it Preemptible (Optional)
```bash
# Add this flag to the above command
--preemptible
```

## 🔍 Troubleshooting

### Common Issues

**1. Permission denied:**
```bash
# Check authentication
gcloud auth list

# Re-authenticate
gcloud auth login
```

**2. API not enabled:**
```bash
gcloud services enable compute.googleapis.com
```

**3. Can't connect to server:**
```bash
# Check firewall rules
gcloud compute firewall-rules list --filter="name:iperf3"

# Check instance status
gcloud compute instances list --filter="name:iperf3-server"
```

**4. Low performance:**
```bash
# Try a larger machine type
gcloud compute instances set-machine-type iperf3-server \
    --machine-type n1-standard-8 \
    --zone europe-west2-a
```

## 📊 Expected Performance

### Network Throughput

| Machine Type  | Expected TCP Download | Expected TCP Upload | Expected UDP  |
|---------------|-----------------------|---------------------|---------------|
| n1-standard-2 | 3-6 Gbps              | 1-3 Gbps            | Up to 8 Gbps  |
| n1-standard-4 | 5-8 Gbps              | 2-5 Gbps            | Up to 10 Gbps |
| n2-standard-4 | 5-8 Gbps              | 2-5 Gbps            | Up to 10 Gbps |

### Real-World Results
- **TCP Download**: 5-8 Gbps typical (depends on client connection)
- **TCP Upload**: 2-5 Gbps typical (depends on client connection)  
- **UDP**: Up to 10 Gbps (server capable)
- **Latency**: Sub-millisecond within same region

## 🌍 Regional Options

### Europe Regions
- **europe-west2** (London) - Good for UK/Europe
- **europe-west1** (Belgium) - Good for Europe
- **europe-central2** (Warsaw) - Good for Eastern Europe

### US Regions (Lower Cost)
- **us-central1** (Iowa) - Lowest costs
- **us-east1** (South Carolina) - Good East Coast

### Asia Regions
- **asia-northeast1** (Tokyo) - Good for Asia
- **asia-southeast1** (Singapore) - Good for Southeast Asia

### Australia & New Zealand Regions  
- **australia-southeast1** (Sydney) - Good for Australia & New Zealand
- **australia-southeast2** (Melbourne) - Good for Australia & southern regions

## 📚 Additional Resources

- **GCP Compute Engine Documentation**: [docs.cloud.google.com](https://cloud.google.com/compute/docs)
- **iPerf3 Official Documentation**: [iperf.fr](https://iperf.fr/iperf-doc.php)
- **GCP Pricing Calculator**: [cloud.google.com/calculator](https://cloud.google.com/calculator)

## 🤝 Support

- **Deployment Issues**: Check this guide or create GitHub issue
- **Performance Questions**: See troubleshooting section
- **Cost Questions**: Use GCP billing dashboard

---

**🎯 Ready to test high-speed networks on Google Cloud Platform!**

**Quick Commands Summary:**
```bash
# Deploy
./deploy-gcp.sh --project YOUR-PROJECT --region europe-west2

# Test  
iperf3 -c YOUR-SERVER-IP -p 5201 -R -t 30 -P 4

# Stop
gcloud compute instances stop iperf3-server --zone=europe-west2-a
```
