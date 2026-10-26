variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for every resource."
  type        = string
  default     = "intern-task-app"
}

variable "ssh_allowed_cidr" {
  description = "The one CIDR allowed to reach SSH (e.g. your public IP as x.x.x.x/32), in both the security group and the host firewall. No default: there is no sane guess for \"my IP\". The host-firewall copy lives in user_data, so changing this later updates the security group only; re-create the instance (-replace) to update ufw too."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid IPv4 CIDR, e.g. 203.0.113.10/32."
  }

  validation {
    condition     = !endswith(var.ssh_allowed_cidr, "/0")
    error_message = "ssh_allowed_cidr must not open SSH to the whole internet."
  }
}

variable "admin_username" {
  description = "Non-root user created by cloud-init, with passwordless sudo."
  type        = string
  default     = "deploy"
}

variable "admin_ssh_public_key" {
  description = "Optional SSH public key installed for admin_username. Without it the user exists but has no way to log in over SSH."
  type        = string
  default     = null
}

variable "ami_id" {
  description = "AMI for the instance. Must be Ubuntu 22.04+ (cloud-init, apt, ufw, docker.io). Default: Ubuntu 24.04 LTS amd64 in us-east-1; never launched in this exercise, so any plausible value works."
  type        = string
  default     = "ami-0360c520857e3138f"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block of the public subnet; must sit inside vpc_cidr."
  type        = string
  default     = "10.0.1.0/24"
}

variable "tags" {
  description = "Extra tags applied to every resource via the provider's default_tags."
  type        = map(string)
  default     = {}
}