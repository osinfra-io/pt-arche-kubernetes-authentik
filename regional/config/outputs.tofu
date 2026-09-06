# Output Values
# https://opentofu.org/docs/language/values/outputs

output "browser_group_policy_bindings" {
  description = "The effective per-host Authentik browser authorization group bindings configured for this module"
  value       = var.browser_group_policy_bindings
}

output "browser_policy_bindings" {
  description = "The per-group Authentik policy bindings created for browser routes, keyed by \"<host>:<group>\""
  value       = authentik_policy_binding.browser_group
}

output "embedded_outpost_name" {
  description = "The name of the built-in embedded outpost, used by the root module's import block to bring it under management"
  value       = local.embedded_outpost_name
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
