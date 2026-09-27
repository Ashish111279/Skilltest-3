output "public_ip" {
  description = "Public IPv4 address for the frontend."
  value       = data.aws_instance.frontend.public_ip
}

output "frontend_url" {
  description = "Public URL for the storefront."
  value       = "http://${data.aws_instance.frontend.public_ip}"
}

output "backend_private_ip" {
  description = "Private IPv4 address of the instance running orders and cart."
  value       = data.aws_instance.backends.private_ip
}
