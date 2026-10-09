# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  browser_group_policy_bindings = {
    agentgateway = {
      groups = ["agentgateway-admins"]
      host   = "https://agentgateway.localhost"
    }
    development = {
      groups = ["all"]
      host   = "https://dev.localhost"
    }
  }

  authentication_policy_ids = {
    for key, policy in data.authentik_policy_expression.authentication_stage_policies : key => policy.id
  }

  authentication_stage_ids = {
    for key, stage in data.authentik_stage.authentication_stages : key => stage.id
  }
}
