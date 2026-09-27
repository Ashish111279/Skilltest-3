data "aws_instance" "frontend" {
  instance_id = var.frontend_instance_id
}

data "aws_instance" "backends" {
  instance_id = var.backend_instance_id
}

locals {
  frontend_security_group_id = sort(tolist(data.aws_instance.frontend.vpc_security_group_ids))[0]
  backend_security_group_id  = sort(tolist(data.aws_instance.backends.vpc_security_group_ids))[0]
}

resource "aws_vpc_security_group_ingress_rule" "frontend_http" {
  security_group_id = local.frontend_security_group_id
  description       = "Public HTTP for the ecommerce frontend"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  lifecycle {
    precondition {
      condition     = var.frontend_instance_id != var.backend_instance_id
      error_message = "The frontend and backend instance IDs must be different."
    }

    precondition {
      condition     = data.aws_instance.frontend.vpc_id == data.aws_instance.backends.vpc_id
      error_message = "Both existing instances must be in the same VPC for private backend communication."
    }

    precondition {
      condition     = data.aws_instance.frontend.public_ip != ""
      error_message = "The frontend instance must have a public IPv4 address for the output URL."
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "remote_backends" {
  for_each = toset([3003, 3004])

  security_group_id            = local.backend_security_group_id
  description                  = "Frontend instance to backend service port ${each.value}"
  referenced_security_group_id = local.frontend_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
}

resource "aws_ssm_document" "frontend_host" {
  name            = "ecommerce-deploy-frontend-${replace(var.frontend_instance_id, "-", "")}"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install Docker and run the frontend, user, and products containers."
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "deployFrontendHost"
      inputs = {
        runCommand = [
          <<-SHELL
          set -euo pipefail
          if ! command -v docker >/dev/null 2>&1; then
            if command -v apt-get >/dev/null 2>&1; then
              apt-get update
              apt-get install -y docker.io
            elif command -v amazon-linux-extras >/dev/null 2>&1; then
              amazon-linux-extras install docker -y
            elif command -v dnf >/dev/null 2>&1; then
              dnf install -y docker
            elif command -v yum >/dev/null 2>&1; then
              yum install -y docker
            else
              echo "No supported package manager found" >&2
              exit 1
            fi
          fi
          systemctl enable --now docker
          docker network inspect ecommerce >/dev/null 2>&1 || docker network create ecommerce
          docker pull ${var.dockerhub_username}/ecommerce-user:${var.image_tag}
          docker pull ${var.dockerhub_username}/ecommerce-products:${var.image_tag}
          docker pull ${var.dockerhub_username}/ecommerce-frontend:${var.image_tag}
          docker rm -f user-service products-service frontend 2>/dev/null || true
          docker run -d --name user-service --restart unless-stopped --network ecommerce -p 3001:3001 ${var.dockerhub_username}/ecommerce-user:${var.image_tag}
          docker run -d --name products-service --restart unless-stopped --network ecommerce -p 3002:3002 ${var.dockerhub_username}/ecommerce-products:${var.image_tag}
          docker run -d --name frontend --restart unless-stopped --network ecommerce -p 80:3000 \
            -e USER_SERVICE_URL=http://user-service:3001 \
            -e PRODUCT_SERVICE_URL=http://products-service:3002 \
            -e ORDER_SERVICE_URL=http://${data.aws_instance.backends.private_ip}:3003 \
            -e CART_SERVICE_URL=http://${data.aws_instance.backends.private_ip}:3004 \
            ${var.dockerhub_username}/ecommerce-frontend:${var.image_tag}
        SHELL
        ]
      }
    }]
  })
}

resource "aws_ssm_document" "backend_host" {
  name            = "ecommerce-deploy-backends-${replace(var.backend_instance_id, "-", "")}"
  document_type   = "Command"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install Docker and run the orders and cart containers."
    mainSteps = [{
      action = "aws:runShellScript"
      name   = "deployBackendHost"
      inputs = {
        runCommand = [
          <<-SHELL
          set -euo pipefail
          if ! command -v docker >/dev/null 2>&1; then
            if command -v apt-get >/dev/null 2>&1; then
              apt-get update
              apt-get install -y docker.io
            elif command -v amazon-linux-extras >/dev/null 2>&1; then
              amazon-linux-extras install docker -y
            elif command -v dnf >/dev/null 2>&1; then
              dnf install -y docker
            elif command -v yum >/dev/null 2>&1; then
              yum install -y docker
            else
              echo "No supported package manager found" >&2
              exit 1
            fi
          fi
          systemctl enable --now docker
          docker network inspect ecommerce >/dev/null 2>&1 || docker network create ecommerce
          docker pull ${var.dockerhub_username}/ecommerce-orders:${var.image_tag}
          docker pull ${var.dockerhub_username}/ecommerce-cart:${var.image_tag}
          docker rm -f orders-service cart-service 2>/dev/null || true
          docker run -d --name orders-service --restart unless-stopped --network ecommerce -p 3003:3003 ${var.dockerhub_username}/ecommerce-orders:${var.image_tag}
          docker run -d --name cart-service --restart unless-stopped --network ecommerce -p 3004:3004 ${var.dockerhub_username}/ecommerce-cart:${var.image_tag}
        SHELL
        ]
      }
    }]
  })
}

resource "aws_ssm_association" "frontend_host" {
  name                             = aws_ssm_document.frontend_host.name
  association_name                 = "ecommerce-frontend-${replace(var.frontend_instance_id, "-", "")}"
  wait_for_success_timeout_seconds = 900

  targets {
    key    = "InstanceIds"
    values = [var.frontend_instance_id]
  }

  depends_on = [aws_ssm_association.backend_host]
}

resource "aws_ssm_association" "backend_host" {
  name                             = aws_ssm_document.backend_host.name
  association_name                 = "ecommerce-backends-${replace(var.backend_instance_id, "-", "")}"
  wait_for_success_timeout_seconds = 900

  targets {
    key    = "InstanceIds"
    values = [var.backend_instance_id]
  }
}
