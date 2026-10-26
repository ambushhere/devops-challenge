locals {
  # The real app from ../../intern-task-app, shipped verbatim inside
  # user_data and built on the instance with the same Dockerfile.
  app_src    = "${path.module}/../../intern-task-app"
  dockerfile = file("${local.app_src}/Dockerfile")

  # The port is not a free choice: it is whatever the Dockerfile sets.
  # Reading it from the file keeps the security group, ufw and the output
  # from drifting if the Dockerfile ever changes.
  app_port      = tonumber(regex("PORT=(\\d+)", local.dockerfile)[0])
  exposed_port  = tonumber(regex("(?m)^EXPOSE\\s+(\\d+)", local.dockerfile)[0])
  app_image     = "intern-task-app:local"
  app_container = "intern-task-app"
  app_dir       = "/opt/intern-task-app"

  admin_user = merge(
    {
      name        = var.admin_username
      gecos       = "intern-task-app admin"
      shell       = "/bin/bash"
      sudo        = "ALL=(ALL) NOPASSWD:ALL"
      lock_passwd = true
    },
    var.admin_ssh_public_key == null ? {} : { ssh_authorized_keys = [var.admin_ssh_public_key] },
  )

  cloud_config = {
    # Only our user; no stock "ubuntu" account.
    users = [local.admin_user]

    package_update = true
    packages       = ["docker.io", "ufw"]

    write_files = [
      {
        path        = "${local.app_dir}/Dockerfile"
        encoding    = "b64"
        content     = filebase64("${local.app_src}/Dockerfile")
        permissions = "0644"
      },
      {
        path        = "${local.app_dir}/.dockerignore"
        encoding    = "b64"
        content     = filebase64("${local.app_src}/.dockerignore")
        permissions = "0644"
      },
      {
        path        = "${local.app_dir}/app/app.py"
        encoding    = "b64"
        content     = filebase64("${local.app_src}/app/app.py")
        permissions = "0644"
      },
      {
        path        = "/etc/systemd/system/${local.app_container}.service"
        permissions = "0644"
        content = templatefile("${path.module}/templates/intern-task-app.service.tftpl", {
          container = local.app_container
          image     = local.app_image
          port      = local.app_port
        })
      },
      {
        path        = "/usr/local/sbin/bootstrap-intern-task-app.sh"
        permissions = "0750"
        content = templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
          ssh_allowed_cidr = var.ssh_allowed_cidr
          port             = local.app_port
          image            = local.app_image
          container        = local.app_container
          app_dir          = local.app_dir
        })
      },
    ]

    # runcmd runs in cloud-init's final stage, after packages are installed.
    runcmd = [["/bin/bash", "/usr/local/sbin/bootstrap-intern-task-app.sh"]]
  }

  user_data = "#cloud-config\n${yamlencode(local.cloud_config)}"
}

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = local.user_data

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  tags = { Name = var.name }

  lifecycle {
    # cloud-init consumes user_data once, at first boot. A later change to
    # it can never reach the running instance, so planning it is either a
    # pointless replacement or a pointless stop/start. Ignore it; to roll
    # out new user_data on purpose, run `terraform apply -replace=aws_instance.app`.
    ignore_changes = [user_data, user_data_base64]

    precondition {
      condition     = local.app_port == local.exposed_port
      error_message = "intern-task-app Dockerfile: ENV PORT and EXPOSE disagree; fix the Dockerfile first."
    }
  }

  # The route must exist before cloud-init runs, or apt and `docker build`
  # on first boot would have no way out.
  depends_on = [aws_route_table_association.public, aws_internet_gateway.main]
}