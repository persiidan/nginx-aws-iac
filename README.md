# nginx-aws-iac — Terraform AWS Infrastructure

## Overview
This project provisions an AWS environment (region **il-central-1**) with:

| Tier | Resources | Purpose |
|------|-----------|---------|
| Network Edge | **Internet Gateway (IGW)**<br>**AWS WAF** | Allows inbound HTTP and outbound egress; protects ALB with security rules |
| Public Subnets (×2) | • **NAT Gateway** (Subnet-1)<br>• **Application Load Balancer** (spans both AZs) | NAT gives the private subnet one-way Internet access; ALB fronts incoming traffic |
| Private Subnet | **EC2** instance running a **Docker-built NGINX** app | Receives traffic from the ALB; egress via NAT only |
| Backend | **S3 Bucket** (moveoterrabe) | Stores Terraform state remotely for team collaboration |

High-level traffic:
* **Inbound**  `Internet → IGW → AWS WAF → ALB → EC2`
* **Outbound** `EC2 → NAT Gateway → Internet`

### Security Features (AWS WAF)
The ALB is protected by **AWS WAF** with the following rules:
- ✅ **Rate Limiting**: Max 2,000 requests per IP (returns HTTP 429 when exceeded)
- ✅ **IP Reputation**: Blocks requests from known malicious IPs (AWS managed list)
- ✅ **Geo-blocking**: **Only allows traffic from Israel (IL)** - blocks all other countries
- ✅ **Request Size**: Blocks requests larger than 8KB (returns HTTP 413)
- ✅ **CloudWatch Monitoring**: All rules send metrics to CloudWatch for visibility

---

## Important Notices
-  The project uses a Docker image from Docker Hub (idanpersi/nginx-port) - very simple image, I included the Dockerfile
-  For VPC and networking purposes I used the existing module from (http://github.com/terraform-aws-modules/terraform-aws-vpc)
-  **Terraform state is stored in S3**: The backend bucket `moveoterrabe` in il-central-1 stores the Terraform state for team collaboration and state locking
-  Updating the Dockerfile will trigger docker-image workflow 
-  Updating any TF related file (i.e. any *.tf and user_data.sh) will trigger Deploy-nginx workflow
-  The Workflow's Terraform can access my AWS account thanks to a dedicated user with policy to enable access
-  **Security Note**: Access to the ALB is geo-restricted to Israel only via AWS WAF rules

## Architecture Diagram

![AWS Infrastructure Architecture](./architecture_diagram.png)

---

## Repository Layout

```
.
├── main.tf
├── variables.tf
├── terraform.tf        # Provider config & S3 backend
├── out.tf              # Outputs (ALB DNS)
└── modules/
    ├── load_balancer/  # ALB, target group, listener, security groups, WAF
    │   ├── alb.tf      # Application Load Balancer configuration
    │   ├── waf.tf      # AWS WAF rules (rate limiting, geo-blocking, etc.)
    │   └── ...
    └── nginx/          # EC2, SG, user-data (installs Docker & runs NGINX)
        ├── nginx.tf    # EC2 instance configuration
        ├── user_data.sh # Boot script to install Docker & run container
        └── ...
```
## Prerequisites
* Terraform ≥ 1.6
* AWS CLI configured with create-vpc permissions
* Optional: an AWS key pair if you need SSH access to the EC2 instance

### How the NGINX Module Works

1. **User-data** (`modules/nginx/user_data.sh`) runs on first boot.  
2. Installs Docker, then **builds** the image from the included `Dockerfile`.  
3. Starts the container, listening on **port 80**.  
4. Security groups allow the ALB to reach port 80; **no inbound Internet traffic** can reach the EC2 directly.

## 1 — Clone the code
```
git clone https://github.com/persiidan/nginx-aws-iac.git
cd nginx-aws-iac
```
## 2 — Initialise Terraform
```
terraform init
```
## 3 — Review (optional but recommended)
```
terraform plan
```
## 4 — Apply the configuration
```
terraform apply
```
↳ confirm with 'yes' when prompted
Terraform outputs the ALB DNS name on success:

## Outputs:
should look like:
```
alb_dns = http://nginx-alb-xxxx.il-central-1.elb.amazonaws.com
```
Open that URL in a browser 

you should see the NGINX welcome page served from the EC2 instance in the private subnet.

> ⚠️ **Note**: Due to AWS WAF geo-blocking rules, **only traffic from Israel (IL) will be allowed**. Requests from other countries will receive an HTTP 403 Forbidden response.

## Testing the WAF Rules

You can test the WAF functionality:

1. **Geo-blocking**: Access the ALB DNS from outside Israel → Should return HTTP 403
2. **Rate limiting**: Send more than 2,000 requests/minute from the same IP → Should return HTTP 429
3. **IP Reputation**: Attempts from known malicious IPs → Blocked automatically

Monitor WAF events in CloudWatch metrics: `nginx-alb-waf` namespace

## Variables You May Override
| Variable | Default | Description |
|----------|---------|-------------|
| aws_region | il-central-1 | Deployment region |
| vpc_name | nginx-vpc | VPC name tag |
| app_port | 80 | Container port exposed to the ALB |

# Destroying Everything
```
terraform destroy
```
All resources—including the VPC—are removed.

# Troubleshooting Tips
* Stuck at "Instance failed health checks" → ensure the container really listens on port 80.

* Timeout reaching ALB DNS → verify security-group rules in the load_balancer and nginx modules.

* Need SSH → add your key pair ID to variables.tf and open port 22 from your IP in the EC2 SG.

* **Getting HTTP 403 Forbidden** → you're likely accessing from outside Israel (WAF geo-blocking in effect)

* **Getting HTTP 429 Too Many Requests** → you've exceeded the 2,000 requests/minute rate limit

* **S3 backend errors** → ensure the S3 bucket `moveoterrabe` exists and you have permissions to read/write Terraform state

* **WAF not working** → verify the WAF web ACL is associated with the ALB in the AWS Console
