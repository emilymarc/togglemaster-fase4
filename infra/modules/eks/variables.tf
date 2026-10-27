variable "project_name" {
  description = "Prefixo do nome do cluster e do node group"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets privadas — onde os worker nodes ficam"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Subnets publicas — onde os load balancers externos ficam"
  type        = list(string)
}
