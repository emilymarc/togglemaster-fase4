# fix: IMDSv2 com hop limit 2: pods (como o driver EBS CSI) conseguem usar a role do nó (LabRole), pq AWS Academy não deixa criar IAM roles.
resource "aws_launch_template" "nodes" {
  name_prefix = "${var.project_name}-nodes-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"

  node_role_arn = data.aws_iam_role.lab_role.arn

  subnet_ids     = var.private_subnet_ids
  instance_types = ["t3.medium"]

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    desired_size = 3
    min_size     = 3
    max_size     = 4
  }

  update_config { max_unavailable = 1 }
}