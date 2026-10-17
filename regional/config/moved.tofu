# Moved Blocks
# https://opentofu.org/docs/language/moved

moved {
  from = authentik_flow.google_authentication[0]
  to   = authentik_flow.google_authentication
}

moved {
  from = authentik_flow.google_enrollment[0]
  to   = authentik_flow.google_enrollment
}

moved {
  from = authentik_flow_stage_binding.google_authentication[0]
  to   = authentik_flow_stage_binding.google_authentication
}

moved {
  from = authentik_flow_stage_binding.google_authentication_login[0]
  to   = authentik_flow_stage_binding.google_authentication_login
}

moved {
  from = authentik_flow_stage_binding.google_enrollment[0]
  to   = authentik_flow_stage_binding.google_enrollment
}

moved {
  from = authentik_flow_stage_binding.google_enrollment_login[0]
  to   = authentik_flow_stage_binding.google_enrollment_login
}

moved {
  from = authentik_group.browser["all"]
  to   = authentik_group.all
}

moved {
  from = authentik_policy_binding.google_authentication_sso[0]
  to   = authentik_policy_binding.google_authentication_sso
}

moved {
  from = authentik_policy_expression.google_authentication_sso[0]
  to   = authentik_policy_expression.google_authentication_sso
}

moved {
  from = authentik_property_mapping_provider_scope.google_proxy[0]
  to   = authentik_property_mapping_provider_scope.google_proxy
}

moved {
  from = authentik_property_mapping_source_oauth.google_application_groups[0]
  to   = authentik_property_mapping_source_oauth.google_application_groups
}

moved {
  from = authentik_property_mapping_source_oauth.google_username[0]
  to   = authentik_property_mapping_source_oauth.google_username
}

moved {
  from = authentik_source_oauth.google[0]
  to   = authentik_source_oauth.google
}

moved {
  from = authentik_stage_identification.default_authentication[0]
  to   = authentik_stage_identification.default_authentication
}

moved {
  from = authentik_stage_user_login.google_enrollment[0]
  to   = authentik_stage_user_login.google_enrollment
}

moved {
  from = authentik_stage_user_write.google_authentication[0]
  to   = authentik_stage_user_write.google_authentication
}

moved {
  from = authentik_stage_user_write.google_enrollment[0]
  to   = authentik_stage_user_write.google_enrollment
}
