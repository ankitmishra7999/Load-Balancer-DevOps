# Look up the latest official Ubuntu 24.04 LTS AMI instead of hardcoding an
# ID - AMI IDs are region-specific and Canonical publishes new ones
# regularly, so a hardcoded ID would eventually go stale.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Reuse the account's default VPC/subnet rather than provisioning a new
# VPC. A custom VPC would need its own subnets, route tables and an
# internet gateway - more to build and more that can slip into a billable
# NAT gateway by accident. The default VPC already has all of that and
# costs nothing extra.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Registers your existing local public key with AWS so you can SSH in.
# Terraform never generates or stores a private key itself - the private
# half never leaves your machine.
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_path)
}

# Security group: open only what this project actually uses.
#   - 22   -> SSH management, restricted to your IP (see allowed_ssh_cidr)
#   - 5000 -> load_balancer_1's Flask API. Per project/docker-compose.yml,
#             this is the ONLY container port-mapped to the host
#             ("5000:5000"). shard_manager_1 and the dynamically spawned
#             ds_server containers all stay on the internal Docker
#             network `pub` and are never reachable from outside the
#             instance, so they need no ingress rule here.
resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH (restricted) and the load balancer app port only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Load balancer HTTP API"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound (apt/docker pull, image builds, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# The instance. Kept free-tier-safe by construction, not by convention:
#   - instance_type can only be t2.micro/t3.micro (enforced in variables.tf)
#   - root volume explicitly capped (root_volume_size_gb, default 20 GiB),
#     well under the 30 GiB/month Free Tier EBS allowance
#   - delete_on_termination = true so `terraform destroy` never leaves an
#     orphaned, still-billable EBS volume behind
#   - no aws_eip anywhere - we rely on the instance's auto-assigned public
#     IP, which is covered by the Free Tier's 750 hrs/month of public
#     IPv4 usage (this offsets AWS's 2024 per-public-IPv4 hourly charge,
#     but only while the account is within its Free Tier window - see the
#     cost note in README.md)
#
# Deliberately no user_data here. Terraform's job stops at "a reachable
# machine exists" - the Ubuntu AMI already boots with sshd running and the
# key from aws_key_pair installed, so SSH access needs nothing extra from
# us. Installing Docker/Compose/Make, hardening SSH, and deploying the app
# are configuration-management concerns and belong to Ansible (see
# ../ansible/), not to provisioning.
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deployer.key_name

  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = var.project_name
  }
}
