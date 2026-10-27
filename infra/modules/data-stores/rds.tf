locals {
  databases = toset(["auth", "flag", "targeting"])
}

resource "aws_db_instance" "postgres" {
  for_each = local.databases

  identifier     = "${var.project_name}-${each.key}-db"
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_encrypted = true

  db_name  = "${each.key}_db"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  monitoring_interval                 = 0
  performance_insights_enabled        = false
  enabled_cloudwatch_logs_exports     = []
  iam_database_authentication_enabled = false

  skip_final_snapshot     = true
  backup_retention_period = 1
}
