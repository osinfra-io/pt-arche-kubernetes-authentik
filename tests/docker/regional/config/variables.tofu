# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "embedded_outpost_id" {
  description = "UUID of the pre-existing Authentik embedded outpost. Written to terraform.auto.tfvars by wait-for-authentik.sh at startup."
  type        = string
}

variable "authentik_insecure" {
  default     = true
  description = "Whether to disable TLS certificate verification for the local Authentik endpoint"
  type        = bool
}

variable "authentik_token" {
  default     = "not-a-secret"
  description = "The Authentik API token used by the local integration test fixture"
  sensitive   = true
  type        = string
}

variable "authentik_url" {
  default     = "https://127.0.0.1:9443"
  description = "The local Authentik base URL used by the local integration test fixture"
  type        = string
}

variable "external_host" {
  default     = "https://gateway.localhost"
  description = "The local external host value used for the proxy provider test fixture"
  type        = string
}

variable "namespace" {
  default     = "authentik"
  description = "The local namespace value used for embedded outpost outputs in the test fixture"
  type        = string
}
