output "instance_public_ip" {
  description = "Public IPv4 address of the instance."
  value       = aws_instance.app.public_ip
}

output "app_port" {
  description = "Port intern-task-app listens on, as set in its Dockerfile."
  value       = local.app_port
}

output "app_url" {
  description = "Convenience URL for the app's health endpoint."
  value       = "http://${aws_instance.app.public_ip}:${local.app_port}/healthz"
}