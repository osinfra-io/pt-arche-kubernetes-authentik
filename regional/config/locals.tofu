# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  all_group_name = "all"

  application_group_attributes = {
    for key, group in var.application_groups : key => jsonencode({
      description = group.description
    })
  }

  application_group_names = {
    for key, group in var.application_groups : group.name => key
  }

  application_group_users = {
    for key, group in var.application_groups : key => [
      for email in group.members : local.google_user_ids_by_email[email]
      if contains(keys(local.google_user_ids_by_email), email)
    ]
  }

  application_groups_enabled   = local.google_oauth_enabled && length(var.application_groups) > 0
  application_groups_requested = length(var.application_groups) > 0

  # Normalize the base URL so a trailing slash in authentik_url does not produce double slashes in
  # the issuer and JWKS URLs.
  authentik_base_url = trimsuffix(var.authentik_url, "/")

  browser_application_names = {
    for key, binding in var.browser_group_policy_bindings : key => trimprefix(binding.host, "https://")
  }

  browser_application_slugs = {
    for key, binding in var.browser_group_policy_bindings : key => replace(replace(replace(trimprefix(key, "https://"), ".", "-"), "/", "-"), "_", "-")
  }

  browser_access_policy_expressions = {
    for key, binding in var.browser_group_policy_bindings : key => <<-EOT
      import json
      from authentik.sources.oauth.models import UserOAuthSourceConnection
      request.debug = True
      requirements = json.loads(${jsonencode(jsonencode(binding))})
      user = request.user
      if not user.is_active:
          return False
      names = requirements["groups"] + requirements["roles"]
      if any(": " in name for name in names):
          email = user.attributes.get("osinfra_google_email", "")
          if (
              not isinstance(email, str)
              or not email
              or email != user.email
              or not UserOAuthSourceConnection.objects.filter(user=user, source__slug="google").exists()
          ):
              return False
      memberships = set(user.all_groups().values_list("name", flat=True))
      return all(
          not required or any(name in memberships for name in required)
          for required in (requirements["groups"], requirements["roles"])
      )
    EOT
  }

  browser_access_policy_names = {
    for key, name in local.browser_application_names : key => "${name} - browser access"
  }

  browser_groups = {
    for group in distinct(flatten([
      for binding in values(var.browser_group_policy_bindings) : concat(binding.groups, binding.roles)
      ])) : group => {
      group = group
    }
    if group != local.all_group_name && !contains(keys(local.application_group_names), group)
  }

  browser_proxy_property_mapping_ids = concat(
    local.proxy_default_property_mapping_ids,
    local.application_groups_enabled ? [authentik_property_mapping_provider_scope.google_proxy.id] : [],
  )

  # Name of the built-in default authentication flow's identification stage. Consumers import
  # the pre-existing object into authentik_stage_identification.default_authentication (same
  # pattern as the embedded outpost import), so this module only adds Google to its "sources"
  # list without touching any of its other live settings.
  default_authentication_identification_stage_name = "default-authentication-identification"

  default_authentication_source_uuids = local.default_authentication_stage_managed ? nonsensitive(authentik_stage_identification.default_authentication.sources) : []

  default_authentication_stage_managed = var.manage_default_authentication_stage

  default_authentication_stage_sources = distinct(concat(
    var.default_authentication_source_uuids,
    local.google_oauth_enabled ? [authentik_source_oauth.google.uuid] : [],
  ))

  # The built-in embedded outpost that runs inside the authentik-server pods. Assigning the proxy
  # provider to it makes each regional server serve forward-auth locally for Istio ext_authz.
  embedded_outpost_name = "authentik Embedded Outpost"

  forward_auth_provider_name = "${var.application_name} forward-auth"

  google_authentication_flow_id = local.google_oauth_enabled ? authentik_flow.google_authentication.uuid : data.authentik_flow.default_source_authentication.id

  google_authentication_user_write_stages = local.google_oauth_enabled ? [authentik_stage_user_write.google_authentication] : []

  google_group_mapping_expression = <<-EOT
    import json
    memberships = json.loads(${jsonencode(jsonencode(var.application_groups))})
    email = info.get("email", "")
    verification = [info[key] for key in ("email_verified", "verified_email") if key in info]
    if not verification or any(value is not True for value in verification) or not isinstance(email, str) or not email:
        raise ValueError("Application access requires a verified Google email")
    email = email.lower()
    return {
        "email": email,
        "attributes": {"osinfra_google_email": email},
        "groups": [group["name"] for group in memberships.values() if email in group["members"]],
    }
  EOT

  google_group_matching_mode = length(var.application_groups) > 0 ? "name_link" : "identifier"

  google_identity_mapping_expression = <<-EOT
    import json
    domains = json.loads(${jsonencode(jsonencode(var.google_internal_domains))})
    email = info.get("email", "")
    verification = [info[key] for key in ("email_verified", "verified_email") if key in info]
    internal = (
        bool(verification)
        and all(value is True for value in verification)
        and isinstance(email, str)
        and email.count("@") == 1
        and email.rsplit("@", 1)[1].lower() == info.get("hd")
        and info.get("hd") in domains
    )
    return {"username": email, "type": "internal" if internal else "external"}
  EOT

  google_oauth_enabled = nonsensitive(var.google_oauth_client_id != "" && var.google_oauth_client_secret != "")

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

  google_source_property_mapping_ids = concat(
    local.google_oauth_enabled ? [authentik_property_mapping_source_oauth.google_username.id] : [],
    local.application_groups_enabled ? [authentik_property_mapping_source_oauth.google_application_groups.id] : [],
  )

  google_user_ids_by_email = {
    for user in local.google_verified_users : user.email => user.pk
  }

  google_verified_users = local.application_groups_requested ? [
    for user in data.authentik_users.google.users : user
    if try(jsondecode(user.attributes).osinfra_google_email, "") == user.email && user.is_active
  ] : []

  # Per-provider issuer mode: the issuer and JWKS live under the application slug.
  # https://docs.goauthentik.io/add-secure-apps/providers/oauth2
  issuer_url = "${local.authentik_base_url}/application/o/${var.application_slug}/"

  jwks_uri = "${local.authentik_base_url}/application/o/${var.application_slug}/jwks/"

  openbao_issuer_url = local.openbao_oidc_enabled ? "${local.authentik_base_url}/application/o/openbao/" : null

  openbao_oidc_enabled = var.openbao_hostname != null

  openbao_redirect_uris = local.openbao_oidc_enabled ? [
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "https://${var.openbao_hostname}/ui/vault/auth/oidc/oidc/callback"
    },
    {
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
      url               = "http://localhost:8250/oidc/callback"
    },
  ] : []

  outpost_authentik_url = var.outpost_authentik_url != null ? var.outpost_authentik_url : var.authentik_url

  outpost_config = jsonencode({
    authentik_host = local.outpost_authentik_url
  })

  outpost_provider_ids = concat(
    [authentik_provider_proxy.gateway.id],
    [for provider in authentik_provider_proxy.browser : provider.id],
  )

  # The embedded outpost is served by the authentik-server Service, which Istio ext_authz
  # forward-auth targets on the HTTP service port at /outpost.goauthentik.io/auth/envoy.
  # https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_envoy
  outpost_service_name = "authentik-server"

  outpost_service_port = 80

  pending_application_members = {
    for key, group in var.application_groups : key => tolist([
      for email in group.members : email
      if !contains(keys(local.google_user_ids_by_email), email)
    ])
  }

  proxy_default_property_mapping_ids = [
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.entitlements.id,
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.proxy.id,
  ]
}
