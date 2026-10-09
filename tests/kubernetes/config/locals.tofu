# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  admin_saml = var.admin_saml == null ? null : merge(var.admin_saml, {
    external_host = "https://agentgateway.localhost"
  })

  browser_group_policy_bindings = merge(
    {
      development = {
        groups = ["all"]
        host   = "https://dev.localhost"
      }
    },
    var.admin_saml == null ? {
      agentgateway = {
        groups = ["agentgateway-admins"]
        host   = "https://agentgateway.localhost"
      }
    } : {},
  )

  authentication_policy_ids = {
    for key, policy in data.authentik_policy_expression.authentication_stage_policies : key => policy.id
  }

  authentication_stage_ids = {
    for key, stage in data.authentik_stage.authentication_stages : key => stage.id
  }
}
