variable "region" {
  type    = string
  default = "us-east-1"
}

variable "app_name" {
  type    = string
  default = "diy-llm"
}

variable "cluster_name" {
  type    = string
  default = "llm-cluster"
}

variable "kubernetes_version" {
  description = "Stay on a version in EKS standard support: extended support costs 6x"
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zone_count" {
  type    = number
  default = 2
}

variable "gpu_instance_type" {
  type    = string
  default = "g4dn.xlarge"
}

variable "cpu_instance_type" {
  type    = string
  default = "t3.large"
}

variable "gpu_instance_desired_size" {
  type    = number
  default = 1
}

variable "cpu_instance_desired_size" {
  type    = number
  default = 1
}
variable "obstack_availability_zone" {
  description = "The obstack node and its EBS volumes stay in this AZ"
  type        = string
  default     = "us-east-1a"
}

variable "obstack_instance_type" {
  description = "ARM (Graviton), for the AL2023 ARM AMI"
  type        = string
  default     = "t4g.large"
}

variable "api_dns" {
  type = object({
    host           = string
    zone           = string
    certificate_id = string
  })
}

variable "grafana_dns" {
  type = object({
    host           = string
    zone           = string
    certificate_id = string
  })
}
