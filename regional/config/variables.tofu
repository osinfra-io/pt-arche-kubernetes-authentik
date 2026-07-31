# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "application_name" {
  default     = "Platform Gateway"
  description = "The display name of the Authentik application for the gateway"
  type        = string
}

variable "application_slug" {
  default     = "gateway"
  description = "The slug of the Authentik application, used in the OIDC issuer URL"
  type        = string
}

variable "authentik_url" {
  description = "The public base URL of the Authentik deployment, used to construct the OIDC issuer and JWKS URLs"
  type        = string

  validation {
    condition     = startswith(var.authentik_url, "https://")
    error_message = "The authentik_url must be a public HTTPS URL (starting with https://)."
  }
}

variable "authorization_flow_slug" {
  default     = "default-provider-authorization-implicit-consent"
  description = "The slug of the Authentik authorization flow to use for the providers"
  type        = string
}

variable "client_id" {
  default     = "gateway"
  description = "The OAuth2 client ID for the gateway OIDC provider"
  type        = string
}

variable "external_host" {
  description = "The public URL of the protected gateway, used as the proxy provider external host"
  type        = string

  validation {
    condition     = startswith(var.external_host, "https://")
    error_message = "The external_host must be a public HTTPS URL (starting with https://)."
  }
}

variable "invalidation_flow_slug" {
  default     = "default-provider-invalidation-flow"
  description = "The slug of the Authentik invalidation flow to use for the providers"
  type        = string
}

variable "namespace" {
  description = "The Kubernetes namespace the authentik-server is deployed into, which serves the embedded outpost"
  type        = string
}

variable "redirect_uris" {
  default     = []
  description = "The list of allowed OAuth2 redirect URIs for the gateway OIDC provider"

  type = list(object({
    matching_mode = string
    url           = string
  }))
}

variable "signing_key_name" {
  default     = "authentik Self-signed Certificate"
  description = "The name of the Authentik certificate-key pair used to sign OIDC tokens"
  type        = string
}
