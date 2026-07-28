# Output Values
# https://opentofu.org/docs/language/values/outputs

output "name" {
  description = "The name of the Authentik Helm release"
  value       = helm_release.authentik.name
}

output "namespace" {
  description = "The namespace Authentik is deployed into"
  value       = helm_release.authentik.namespace
}
