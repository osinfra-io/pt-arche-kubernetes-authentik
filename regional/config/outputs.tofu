# Output Values
# https://opentofu.org/docs/language/values/outputs

output "application_groups" {
  description = "Managed non-superuser application groups keyed by stable identifiers"
  value       = authentik_group.application
}

output "browser_group_policy_bindings" {
  description = "The effective per-host Authentik browser authorization group bindings configured for this module"
  value       = var.browser_group_policy_bindings
}

output "browser_policy_bindings" {
  description = "The per-group Authentik policy bindings created for browser routes, keyed by \"<host>:<group>\""
  value       = authentik_policy_binding.browser_group
}

output "default_authentication_identification_stage_name" {
  description = "The name of the built-in default authentication flow's identification stage, used by the root module's import block to bring it under management"
  value       = local.default_authentication_identification_stage_name
}

output "default_authentication_source_uuids" {
  description = "The source UUIDs assigned to the default authentication identification stage when Google OAuth is enabled"
  value       = nonsensitive(length(authentik_stage_identification.default_authentication) > 0 ? authentik_stage_identification.default_authentication[0].sources : [])
}

output "default_authentication_stage_managed" {
  description = "Whether the shared default authentication identification stage remains under management"
  value       = length(authentik_stage_identification.default_authentication) > 0
}

output "embedded_outpost_name" {
  description = "The name of the built-in embedded outpost, used by the root module's import block to bring it under management"
  value       = local.embedded_outpost_name
}

output "google_authentication_user_write_stages" {
  description = "Google-only stages updating existing source users without creating accounts"
  value       = authentik_stage_user_write.google_authentication
}

output "google_oauth_source_enabled" {
  description = "Whether the optional Google Authentik source was created (true when both OAuth credential inputs are set)"
  value       = length(authentik_source_oauth.google) > 0
}

output "issuer_url" {
  description = "The Authentik OIDC issuer URL for the gateway application"
  value       = local.issuer_url
}

output "jwks_uri" {
  description = "The Authentik OIDC JWKS URI for the gateway application"
  value       = local.jwks_uri
}

output "outpost_namespace" {
  description = "The namespace of the authentik-server that serves the embedded outpost for Istio ext_authz forward-auth"
  value       = var.namespace
}

output "outpost_service_name" {
  description = "The Kubernetes Service name of the authentik-server embedded outpost for the Istio ext_authz ExtensionProvider"
  value       = local.outpost_service_name
}

output "outpost_service_port" {
  description = "The Kubernetes Service port of the authentik-server embedded outpost for the Istio ext_authz ExtensionProvider"
  value       = local.outpost_service_port
}

output "pending_application_members" {
  description = "Declared members awaiting a verified Google sign-in; no accounts or passwords are pre-provisioned"
  value       = local.pending_application_members
}
