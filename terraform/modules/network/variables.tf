variable "pais" {
  description = "Código de país (ar, cl, co, mx) — usado para nombrar y tagear los recursos"
  type        = string
}

variable "entorno" {
  description = "prod o preprod"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC. Cada combinación país+entorno debe usar un rango distinto y sin superposición si en algún momento se peerean o se conectan por Transit Gateway"
  type        = string
}

variable "azs" {
  description = "Availability Zones a usar dentro de us-east-1"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs para las subnets públicas (una por AZ), usadas por el ALB"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs para las subnets privadas (una por AZ), usadas por ECS Fargate y Lambda"
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "CIDRs para las subnets de datos (una por AZ), usadas por Aurora — sin salida a Internet"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = 1 solo NAT Gateway (más barato, recomendado para preprod). false = 1 NAT por AZ (alta disponibilidad, recomendado para prod)"
  type        = bool
  default     = true
}
