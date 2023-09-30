### Provider
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0"
    }
  }
}

locals {
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)
  region     = "us-west-2"
  account_id = data.aws_caller_identity.current.account_id
}

provider "aws" {
  region = local.region
}

data "aws_availability_zones" "available" {}
data "aws_caller_identity" "current" {}

#====================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.0.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 52)]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  manage_default_network_acl    = true
  manage_default_route_table    = true
  manage_default_security_group = true

  default_network_acl_tags = {
    Name = "${var.name}-default"
  }

  default_route_table_tags = {
    Name = "${var.name}-default"
  }

  default_security_group_tags = {
    Name = "${var.name}-default"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Name        = "${var.name}-eks"
    Environment = var.environment
  }
}

module "eks" {
  # forked from terraform-aws-modules/eks/aws, fixes deprecated resolve_conflicts issue
  source = "github.com/cloudacademy/terraform-aws-eks"

  cluster_name = "${var.name}-eks-${var.environment}"

  cluster_version = var.k8s.version

  cluster_endpoint_public_access   = true
  attach_cluster_encryption_policy = false
  create_iam_role                  = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  aws_auth_roles = [

  ]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      use_custom_launch_template = false
      create_iam_role            = true

      instance_types = var.k8s.instance_types
      capacity_type  = var.k8s.capacity_type

      disk_size = var.k8s.disk_size

      min_size     = var.k8s.min_size
      max_size     = var.k8s.max_size
      desired_size = var.k8s.desired_size

      block_device_mappings = {}
      ebs_optimized         = true

      credit_specification = {
        cpu_credits = "standard"
      }
    }
  }

  //don't do in production - this is for demo/lab purposes only
  create_kms_key            = false
  cluster_encryption_config = {}

  tags = {
    Name        = "${var.name}-eks"
    Environment = var.environment
  }
}
