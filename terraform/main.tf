provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

#######################
# VPC & NETWORKING
#######################

resource "aws_vpc" "vulnerable_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vulnerable-vpc"
  }
}

resource "aws_internet_gateway" "vulnerable_igw" {
  vpc_id = aws_vpc.vulnerable_vpc.id

  tags = {
    Name = "vulnerable-igw"
  }
}

resource "aws_route_table" "vulnerable_rt" {
  vpc_id = aws_vpc.vulnerable_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vulnerable_igw.id
  }

  tags = {
    Name = "vulnerable-public-rt"
  }
}

resource "aws_subnet" "vulnerable_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.vulnerable_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.vulnerable_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "vulnerable-public-subnet-${count.index}"
  }
}

resource "aws_route_table_association" "vulnerable_assoc" {
  count          = 2
  subnet_id      = aws_subnet.vulnerable_subnet[count.index].id
  route_table_id = aws_route_table.vulnerable_rt.id
}

#######################
# IAM ROLES
#######################

resource "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRoleCLEY"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node_role" {
  name = "eksNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

#######################
# EKS CLUSTER
#######################

resource "aws_eks_cluster" "vulnerable_cluster" {
  name     = "eks-vulnerable"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.29"

  vpc_config {
    subnet_ids              = aws_subnet.vulnerable_subnet[*].id
    endpoint_public_access  = true
    endpoint_private_access = false
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_service_policy
  ]
}

#######################
# EKS NODE GROUP
#######################

resource "aws_eks_node_group" "vulnerable_nodes" {
  cluster_name    = aws_eks_cluster.vulnerable_cluster.name
  node_group_name = "vulnerable-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.vulnerable_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  ami_type        = "AL2_x86_64"
  instance_types  = ["t3.medium"]

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = []
  }

  tags = {
    Name = "vulnerable-node"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_readonly
  ]
}
