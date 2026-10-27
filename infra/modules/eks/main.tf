resource "aws_eks_cluster" "main" {
  name = "${var.project_name}-cluster"

  version = "1.36"

  role_arn = data.aws_iam_role.lab_role.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  enabled_cluster_log_types = ["api", "audit"]
}