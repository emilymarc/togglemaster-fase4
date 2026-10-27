resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"

  node_role_arn = data.aws_iam_role.lab_role.arn

  subnet_ids     = var.private_subnet_ids
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  update_config { max_unavailable = 1 }

}