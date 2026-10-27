output "database_urls" {
  description = "postgres://user:senha@host:5432/<svc>_db, por servico"
  sensitive   = true
  value = {
    for k, db in aws_db_instance.postgres :
    k => "postgres://${var.db_username}:${var.db_password}@${db.endpoint}/${k}_db"
  }
}

output "redis_url" {
  value = "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"
}

output "sqs_queue_url" {
  value = aws_sqs_queue.events.url
}

output "dynamodb_table" {
  value = aws_dynamodb_table.analytics.name
}

output "rds_endpoints" {
  description = "Endpoints crus, para inspecao e troubleshooting"
  value       = { for k, v in aws_db_instance.postgres : k => v.endpoint }
}
