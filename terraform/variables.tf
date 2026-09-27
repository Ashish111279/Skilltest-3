variable "aws_region" {
  description = "AWS region for the application."
  type        = string
  default     = "us-east-1"
}

variable "frontend_instance_id" {
  description = "Existing EC2 instance for the frontend, user, and products containers."
  type        = string
  default     = "i-037d7985c9ea0cd09"
}

variable "backend_instance_id" {
  description = "Existing EC2 instance for the orders and cart containers."
  type        = string
  default     = "i-0c8b52ea004883370"
}

variable "dockerhub_username" {
  description = "Docker Hub namespace containing the public service images."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]*$", var.dockerhub_username))
    error_message = "Provide a Docker Hub username without a repository or tag suffix."
  }
}

variable "image_tag" {
  description = "Tag used for all five Docker Hub images."
  type        = string
  default     = "latest"
}
