# Output Values
# https://opentofu.org/docs/language/values/outputs

output "issuer_url" {
  description = "The Authentik OIDC issuer URL for the gateway application"
  value       = local.issuer_url
}

output "jwks_uri" {
  description = "The Authentik OIDC JWKS URI for the gateway application"
  value       = local.jwks_uri
}

output "outpost_namespace" {
  description = "The namespace of the managed proxy outpost that serves Istio ext_authz forward-auth"
  value       = var.namespace
}

output "outpost_service_name" {
  description = "The Kubernetes Service name of the managed proxy outpost for the Istio ext_authz ExtensionProvider"
  value       = local.outpost_service_name
}

output "outpost_service_port" {
  description = "The Kubernetes Service port of the managed proxy outpost for the Istio ext_authz ExtensionProvider"
  value       = local.outpost_service_port
}
