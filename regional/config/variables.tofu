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

variable "browser_group_policy_bindings" {
  description = "Per-host Authentik browser policy bindings. Each host creates a dedicated proxy application and binds every listed Authentik group to that application so browser routes can enforce group membership."
  type = map(object({
    groups = list(string)
    host   = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for binding in values(var.browser_group_policy_bindings) :
      startswith(binding.host, "https://") && length(binding.groups) > 0 && length(distinct(binding.groups)) == length(binding.groups) && alltrue([
        for group in binding.groups : length(trimspace(group)) > 0
      ])
    ])
    error_message = "Each browser_group_policy_bindings entry must declare a public HTTPS host and a non-empty, duplicate-free list of Authentik group names."
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

variable "default_authentication_source_uuids" {
  default     = []
  description = "UUIDs of existing sources assigned to the shared default authentication identification stage; preserved when the optional Google source is added"
  type        = list(string)

  validation {
    condition     = length(distinct(var.default_authentication_source_uuids)) == length(var.default_authentication_source_uuids)
    error_message = "The default_authentication_source_uuids list must not contain duplicates."
  }
}

variable "default_authentication_stage_settings" {
  description = "Complete existing configuration of the shared default authentication identification stage, including explicit null values for unlinked stages and flows"
  type = object({
    captcha_stage             = string
    case_insensitive_matching = bool
    enable_remember_me        = bool
    enrollment_flow           = string
    password_stage            = string
    passwordless_flow         = string
    pretend_user_exists       = bool
    recovery_flow             = string
    show_matched_user         = bool
    show_source_labels        = bool
    user_fields               = list(string)
    webauthn_stage            = string
  })

  validation {
    condition     = length(var.default_authentication_stage_settings.user_fields) > 0
    error_message = "The default_authentication_stage_settings user_fields list must not be empty."
  }
}

variable "external_host" {
  description = "The public URL of the protected gateway, used as the proxy provider external host"
  type        = string

  validation {
    condition     = startswith(var.external_host, "https://")
    error_message = "The external_host must be a public HTTPS URL (starting with https://)."
  }
}

variable "google_oauth_client_id" {
  default     = ""
  description = "The OAuth client ID for the optional Google source in Authentik; leave empty to disable the source."
  type        = string
}

variable "google_oauth_client_secret" {
  default     = ""
  description = "The OAuth client secret for the optional Google source in Authentik; leave empty to disable the source."
  sensitive   = true
  type        = string
}

variable "invalidation_flow_slug" {
  default     = "default-provider-invalidation-flow"
  description = "The slug of the Authentik invalidation flow to use for the providers"
  type        = string
}

variable "manage_default_authentication_stage" {
  default     = false
  description = "Whether to manage the imported shared default authentication identification stage; keep true while disabling Google, then remove the state address before setting false"
  type        = bool

  validation {
    condition     = var.google_oauth_client_id == "" || var.google_oauth_client_secret == "" || var.manage_default_authentication_stage
    error_message = "manage_default_authentication_stage must be true when Google OAuth credentials are configured."
  }
}

variable "namespace" {
  description = "The Kubernetes namespace the authentik-server is deployed into, which serves the embedded outpost"
  type        = string
}

variable "outpost_authentik_url" {
  default     = null
  description = "The browser-accessible Authentik base URL used by the embedded outpost; defaults to authentik_url"
  nullable    = true
  type        = string

  validation {
    condition = var.outpost_authentik_url == null ? true : anytrue([
      startswith(var.outpost_authentik_url, "https://"),
      startswith(var.outpost_authentik_url, "http://localhost:"),
      startswith(var.outpost_authentik_url, "http://127.0.0.1:"),
    ])
    error_message = "The outpost_authentik_url must use HTTPS, except for local development URLs on localhost or 127.0.0.1."
  }
}

variable "redirect_uris" {
  default     = []
  description = "The list of allowed OAuth2 redirect URIs for the gateway OIDC provider"

  type = list(object({
    matching_mode     = string
    redirect_uri_type = optional(string, "authorization")
    url               = string
  }))
}

variable "signing_key_name" {
  default     = "authentik Self-signed Certificate"
  description = "The name of the Authentik certificate-key pair used to sign OIDC tokens"
  type        = string
}
