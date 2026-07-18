output "instance_public_ip" {
  description = "Public IP of the EC2 instance."
  value       = aws_instance.app.public_ip
}

output "ssh_command" {
  description = "Ready-to-paste SSH command using the generated project keypair."
  value       = "ssh -i ~/.ssh/lb-devops-key ubuntu@${aws_instance.app.public_ip}"
}

output "app_url" {
  description = "URL for the load balancer's /status endpoint once containers are up (run `make all` on the instance first)."
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}/status"
}
