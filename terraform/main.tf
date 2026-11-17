terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "lab-my-tf-state-w1pyaa"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "lab-my-tf-lockid"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_lightsail_container_service" "python_webapp_service" {
  name        = "python-webapp-service"
  power       = "nano"
  scale       = 1
  is_disabled = false

  private_registry_access {
    ecr_image_puller_role {
      is_active = true
    }
  }
}
