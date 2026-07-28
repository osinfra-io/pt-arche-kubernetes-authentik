# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_version" {
  default     = "2026.5.6"
  description = "The Authentik Helm chart and application version to install"
  type        = string
}

variable "chart_repository" {
  default     = "https://charts.goauthentik.io"
  description = "The repository to pull the Authentik Helm chart from"
  type        = string
}

variable "existing_secret" {
  description = "Name of an existing Kubernetes Secret providing the Authentik environment (AUTHENTIK_SECRET_KEY, AUTHENTIK_POSTGRESQL__PASSWORD, AUTHENTIK_BOOTSTRAP_TOKEN, AUTHENTIK_BOOTSTRAP_PASSWORD). Mounted into the server and worker via envFrom so no secrets are stored in the Helm release."
  type        = string
}

variable "external_database_host" {
  description = "The host of the external PostgreSQL database (Cloud SQL private IP)"
  type        = string
}

variable "external_database_name" {
  default     = "authentik"
  description = "The name of the external PostgreSQL database"
  type        = string
}

variable "external_database_port" {
  default     = 5432
  description = "The port of the external PostgreSQL database"
  type        = number
}

variable "external_database_user" {
  default     = "authentik"
  description = "The user for the external PostgreSQL database"
  type        = string
}

variable "namespace" {
  description = "The Kubernetes namespace to deploy Authentik into"
  type        = string
}

variable "server_replicas" {
  default     = 2
  description = "The number of Authentik server replicas to run"
  type        = number
}

variable "server_resources_limits_memory" {
  default     = "1Gi"
  description = "The memory limit for the Authentik server"
  type        = string
}

variable "server_resources_requests_cpu" {
  default     = "200m"
  description = "The CPU request for the Authentik server"
  type        = string
}

variable "server_resources_requests_memory" {
  default     = "512Mi"
  description = "The memory request for the Authentik server"
  type        = string
}

variable "worker_replicas" {
  default     = 1
  description = "The number of Authentik worker replicas to run"
  type        = number
}

variable "worker_resources_limits_memory" {
  default     = "512Mi"
  description = "The memory limit for the Authentik worker"
  type        = string
}

variable "worker_resources_requests_cpu" {
  default     = "100m"
  description = "The CPU request for the Authentik worker"
  type        = string
}

variable "worker_resources_requests_memory" {
  default     = "256Mi"
  description = "The memory request for the Authentik worker"
  type        = string
}
