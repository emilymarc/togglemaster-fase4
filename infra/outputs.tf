output "cluster_name" {
  description = "Use em: aws eks update-kubeconfig --name <isto>"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "database_urls" {
  sensitive = true
  value     = module.data_stores.database_urls
}

output "redis_url" {
  value = module.data_stores.redis_url
}

output "sqs_queue_url" {
  value = module.data_stores.sqs_queue_url
}

output "dynamodb_table" {
  value = module.data_stores.dynamodb_table
}

output "rds_endpoints" {
  value = module.data_stores.rds_endpoints
}
