variable "project_name" {
  description = "Prefixo no nome de todos os recursos de dados"
  type        = string
}

variable "vpc_id" {
  description = "VPC onde o security group e criado"
  type        = string
}

variable "vpc_cidr" {
  description = "Faixa da VPC — unica origem liberada para 5432 e 6379"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets privadas para RDS e ElastiCache"
  type        = list(string)
}

variable "db_username" {
  description = "Usuario master das instancias RDS"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Senha master das instancias RDS"
  type        = string
  sensitive   = true
}
