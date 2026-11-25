terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "lab-my-tf-state-w1pyaa"
    key            = "minishop/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "lab-my-tf-lockid"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "catalog_image_uri" {
  description = "Full ECR URI for minishop-catalog image"
  type        = string
}

variable "order_image_uri" {
  description = "Full ECR URI for minishop-order image"
  type        = string
}

data "aws_ecr_repository" "catalog" {
  name = "minishop-catalog"
}

data "aws_ecr_repository" "order" {
  name = "minishop-order"
}

resource "aws_lightsail_container_service" "minishop_service" {
  name        = "minishop-service"
  power       = "small"
  scale       = 1
  is_disabled = false

  private_registry_access {
    ecr_image_puller_role {
      is_active = true
    }
  }
}

data "aws_iam_policy_document" "ecr_lightsail_pull" {
  statement {
    sid    = "AllowLightsailPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_lightsail_container_service.minishop_service.private_registry_access[0].ecr_image_puller_role[0].principal_arn]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }
}

resource "aws_ecr_repository_policy" "catalog_policy" {
  repository = data.aws_ecr_repository.catalog.name
  policy     = data.aws_iam_policy_document.ecr_lightsail_pull.json
}

resource "aws_ecr_repository_policy" "order_policy" {
  repository = data.aws_ecr_repository.order.name
  policy     = data.aws_iam_policy_document.ecr_lightsail_pull.json
}

resource "aws_lightsail_container_service_deployment_version" "minishop_deployment" {
  depends_on = [
    aws_ecr_repository_policy.catalog_policy,
    aws_ecr_repository_policy.order_policy
  ]

  service_name = aws_lightsail_container_service.minishop_service.name

  container {
    container_name = "catalog"
    image          = var.catalog_image_uri

    ports = {
      8001 = "HTTP"
    }
  }

  container {
    container_name = "order"
    image          = var.order_image_uri

    ports = {
      8002 = "HTTP"
    }

    environment = {
      CATALOG_URL = "http://localhost:8001"
    }
  }

  public_endpoint {
    container_name = "order"
    container_port = 8002

    health_check {
      healthy_threshold   = 2
      unhealthy_threshold = 3
      timeout_seconds     = 5
      interval_seconds    = 10
      path                = "/health"
      success_codes       = "200-399"
    }
  }
}

output "minishop_url" {
  value = aws_lightsail_container_service.minishop_service.url
}