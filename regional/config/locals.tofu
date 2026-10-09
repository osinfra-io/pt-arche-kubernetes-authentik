# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  application_group_attributes = {
    for key, group in var.application_groups : key => jsonencode({
      description = group.description
    })
  }

  application_groups_enabled_count   = local.google_oauth_enabled && length(var.application_groups) > 0 ? 1 : 0
  application_groups_requested_count = length(var.application_groups) > 0 ? 1 : 0

  application_group_names = {
    for key, group in var.application_groups : group.name => key
  }

  application_group_users = {
    for key, group in var.application_groups : key => [
      for email in group.members : local.google_user_ids_by_email[email]
      if contains(keys(local.google_user_ids_by_email), email)
    ]
  }

  browser_groups = {
    for group in distinct([for item in local.browser_group_policy_bindings : item.group]) : group => {
      group = group
    }
    if group != local.all_group_name && !contains(keys(local.application_group_names), group)
  }

  browser_policy_group_ids = merge(
    { (local.all_group_name) = authentik_group.all.id },
    { for name, group in authentik_group.browser : name => group.id },
    { for key, group in authentik_group.application : group.name => group.id },
  )

  google_group_mapping_expression = <<-EOT
    import json
    memberships = json.loads(${jsonencode(jsonencode(var.application_groups))})
    email = info.get("email", "")
    verified = info.get("email_verified", info.get("verified_email"))
    if verified is not True or not isinstance(email, str) or not email:
        raise ValueError("Application access requires a verified Google email")
    email = email.lower()
    return {
        "email": email,
        "attributes": {"osinfra_google_email": email},
        "groups": [group["name"] for group in memberships.values() if email in group["members"]],
    }
  EOT

  google_proxy_mapping_expression = <<-EOT
    from authentik.sources.oauth.models import UserOAuthSourceConnection
    attributes = dict(request.user.group_attributes(request))
    headers = {
        key: value for key, value in attributes.get("additionalHeaders", {}).items()
        if not key.lower().startswith("x-authentik-")
    }
    email = request.user.attributes.get("osinfra_google_email", "")
    verified = (
        request.user.is_active
        and isinstance(email, str)
        and email != ""
        and email == request.user.email
        and UserOAuthSourceConnection.objects.filter(user=request.user, source__slug="google").exists()
    )
    headers["X-authentik-osinfra-google-email"] = email if verified else ""
    attributes["additionalHeaders"] = headers
    return {
        "ak_proxy": {
            "user_attributes": attributes,
            "is_superuser": request.user.is_superuser,
        }
    }
  EOT

  browser_proxy_property_mapping_ids = local.application_groups_enabled_count > 0 ? [
    authentik_property_mapping_provider_scope.google_proxy[0].id,
  ] : null

  google_group_matching_mode = length(var.application_groups) > 0 ? "name_link" : "identifier"

  google_authentication_flow_id = local.application_groups_enabled_count > 0 ? authentik_flow.google_authentication[0].uuid : data.authentik_flow.default_source_authentication.id

  google_source_property_mapping_ids = concat(
    [for mapping in authentik_property_mapping_source_oauth.google_username : mapping.id],
    [for mapping in authentik_property_mapping_source_oauth.google_application_groups : mapping.id],
  )

  google_verified_users = [
    for user in flatten([for result in data.authentik_users.google : result.users]) : user
    if try(jsondecode(user.attributes).osinfra_google_email, "") == user.email && user.is_active
  ]

  google_user_ids_by_email = {
    for user in local.google_verified_users : user.email => user.pk
  }

  pending_application_members = {
    for key, group in var.application_groups : key => tolist([
      for email in group.members : email
      if !contains(keys(local.google_user_ids_by_email), email)
    ])
  }

  all_group_name = "all"

  # The built-in embedded outpost that runs inside the authentik-server pods. Assigning the proxy
  # provider to it makes each regional server serve forward-auth locally for Istio ext_authz.
  embedded_outpost_name = "authentik Embedded Outpost"

  # Name of the built-in default authentication flow's identification stage. Consumers import
  # the pre-existing object into authentik_stage_identification.default_authentication (same
  # pattern as the embedded outpost import), so this module only adds Google to its "sources"
  # list without touching any of its other live settings.
  default_authentication_identification_stage_name = "default-authentication-identification"

  google_oauth_enabled = var.google_oauth_client_id != "" && var.google_oauth_client_secret != ""

  # Normalize the base URL so a trailing slash in authentik_url does not produce double slashes in
  # the issuer and JWKS URLs.
  authentik_base_url = trimsuffix(var.authentik_url, "/")

  # Per-provider issuer mode: the issuer and JWKS live under the application slug.
  # https://docs.goauthentik.io/add-secure-apps/providers/oauth2
  issuer_url = "${local.authentik_base_url}/application/o/${var.application_slug}/"

  outpost_authentik_url = var.outpost_authentik_url != null ? var.outpost_authentik_url : var.authentik_url

  jwks_uri = "${local.authentik_base_url}/application/o/${var.application_slug}/jwks/"

  # The embedded outpost is served by the authentik-server Service, which Istio ext_authz
  # forward-auth targets on the HTTP service port at /outpost.goauthentik.io/auth/envoy.
  # https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_envoy
  outpost_service_name = "authentik-server"

  outpost_service_port = 80
}
