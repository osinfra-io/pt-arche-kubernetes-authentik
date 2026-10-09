# Output Values
# https://opentofu.org/docs/language/values/outputs

output "application" {
  description = "Administrator browser application"
  value       = authentik_application.admins
}

output "authorization_bindings" {
  description = "Ordered source, post-source denial, and consent stage bindings"
  value = {
    consent = authentik_flow_stage_binding.consent
    deny    = authentik_flow_stage_binding.deny
    source  = authentik_flow_stage_binding.source
  }
}

output "group" {
  description = "Non-superuser application group whose membership is reconciled by the SAML source"
  value       = authentik_group.admins
}

output "policy_expressions" {
  description = "Application-entry and refreshed-membership expression policies"
  value = {
    application = local.application_expression
    expiry      = local.expiry_expression
    membership  = local.membership_expression
    nonmember   = local.nonmember_expression
  }
}

output "provider" {
  description = "Administrator proxy provider to register with the embedded outpost"
  value       = authentik_provider_proxy.admins
}

output "source" {
  description = "Signed Google Workspace SAML source"
  value       = authentik_source_saml.google
}

output "source_expression" {
  description = "Google assertion validation and restricted group mapping expression"
  value       = local.source_expression
}
