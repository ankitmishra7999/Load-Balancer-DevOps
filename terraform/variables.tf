variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Name prefix applied to every tagged/named resource, so they're easy to find and to delete."
  type        = string
  default     = "lb-devops"
}

variable "instance_type" {
  description = "EC2 instance type. Restricted to Free Tier eligible types (see validation below)."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "instance_type must be t2.micro or t3.micro to stay AWS Free Tier eligible."
  }
}

variable "root_volume_size_gb" {
  description = <<-EOT
    Root EBS volume size in GiB. Free Tier covers up to 30 GiB/month of
    gp2/gp3 storage. 8 GiB was tried first and measured too small in
    practice: Ubuntu + Docker Engine alone uses ~4-5 GiB, leaving too
    little headroom to build the mysql:8.0-debian-based ds_server image
    (base layers + build cache). 20 GiB leaves comfortable headroom while
    staying well under the 30 GiB free allowance.
  EOT
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size_gb <= 30
    error_message = "root_volume_size_gb must stay at or under 30 GiB to remain within the Free Tier EBS allowance."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the local SSH public key installed on the instance for login."
  type        = string
  default     = "~/.ssh/lb-devops-key.pub"
}

variable "allowed_ssh_cidr" {
  description = <<-EOT
    CIDR allowed to SSH (port 22) into the instance. Set this to your own
    IP as /32, not 0.0.0.0/0. Codespaces egress IPs are ephemeral, so if
    you reconnect from a new Codespace, update this in terraform.tfvars
    and re-run `terraform apply` (a security-group-only change, no
    instance replacement, no extra cost).
  EOT
  type        = string
}

variable "app_port" {
  description = "Port the load balancer listens on - must match the host port mapping in docker-compose.yml (currently 5000:5000)."
  type        = number
  default     = 5000
}
