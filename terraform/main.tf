terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  project           = var.project
  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = "${var.aws_region}a"
}

module "sg" {
  source = "./modules/sg"

  project = var.project
  vpc_id  = module.vpc.vpc_id
  my_ip   = var.my_ip
}

module "ec2" {
  source = "./modules/ec2"

  project       = var.project
  subnet_id     = module.vpc.subnet_id
  sg_id         = module.sg.sg_id
  key_name      = var.key_name
  instance_type = var.instance_type
}
