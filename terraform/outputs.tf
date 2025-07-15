output "cluster_name" {
  value = aws_eks_cluster.vulnerable_cluster.name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${aws_eks_cluster.vulnerable_cluster.name} --region ${var.region}"
}