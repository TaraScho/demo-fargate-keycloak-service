variable "region" {
  description = "The AWS region to deploy in."
  type        = string
}

variable "frontend_aws_access_key_id" {
  description = "front end account configuration"
  type        = string
  sensitive   = true
}

variable "frontend_aws_secret_access_key" {
  description = "front end account configuration"
  type        = string
  sensitive   = true
}

variable "aws_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {
    application = "serverless-image-processor"
    env = "aws_frontend"
  }
}

variable "cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "List of CIDR blocks for the private subnets"
  type        = list(string)
  default = [ "10.0.1.0/24" ]
}

variable "public_subnets" {
  description = "List of CIDR blocks for the public subnets"
  type        = list(string)
  default     = [ "10.0.2.0/24", "10.0.3.0/24" ] 
}

variable "availability_zones" {
  description = "List of availability zones in which to create subnets"
  type        = list(string)
  default = [ "us-east-1a", "us-east-1b" ]
}

variable "name" {
  description = "Name of Fargate Service"
  type        = string
  default     = "keycloak"
}

variable "container_image" {
  description = "The container image to use for the Keycloak service"
  type        = string
  default     = "quay.io/keycloak/keycloak:20.0.5"
}

variable "container_port" {
  description = "The port on which the container listens"
  type        = number
  default     = 8080 
}

variable "health_check_path" {
  description = "The path to use for the health check"
  type        = string
  default     = "/health"
}

variable "keycloak_admin_password" {
  description = "The password for the Keycloak admin user"
  type        = string
  sensitive  = true
  default     = "admin"
}

variable "keycloak_admin" {
  description = "The Keycloak admin user"
  type        = string
  sensitive  = true
  default     = "admin"
}