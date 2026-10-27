variable "project_name" {
  description = "Prefixo usado no Name de todos os recursos de rede"
  type        = string
}

variable "azs" {
  description = "Zonas de disponibilidade — uma subnet publica e uma privada por AZ"
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "Este modulo espera exatamente 2 AZs (o count das subnets e fixo em 2)."
  }
}
