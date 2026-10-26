resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

# A subnet is "public" only if all of these hold:
#   1. the VPC has an internet gateway attached,
#   2. the subnet's route table sends 0.0.0.0/0 to that gateway,
#   3. instances in it get a public IPv4 address.
# Missing any one of them leaves the instance unreachable from outside.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.name}-public" }
}

# Without an explicit association the subnet falls back to the VPC's main
# route table, which only has the local route.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app" {
  name        = var.name
  description = "SSH from one admin CIDR, the app port from anywhere"
  vpc_id      = aws_vpc.main.id

  tags = { Name = var.name }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  description       = "SSH from the admin CIDR only"
  cidr_ipv4         = var.ssh_allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  security_group_id = aws_security_group.app.id
  description       = "intern-task-app HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = local.app_port
  to_port           = local.app_port
}

# Terraform removes AWS's default allow-all egress rule from security groups
# it manages, so outbound has to be granted explicitly: cloud-init needs it
# for apt and for pulling the python base image during `docker build`.
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound for apt and image pulls"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}