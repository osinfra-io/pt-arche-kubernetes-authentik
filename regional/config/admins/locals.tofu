# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  access_token_validity = "seconds=${var.configuration.refresh_seconds - 1}"
  application_name      = "Agentgateway administrators"
  attribute_key         = "${var.configuration.slug}-membership"
  source_flows = {
    authentication = "authentication"
    enrollment     = "enrollment"
  }

  membership_expression = <<-EOT
    import time
    state = request.user.attributes.get(${jsonencode(local.attribute_key)}, {})
    return (
        state.get("member") is True
        and isinstance(state.get("checked_at"), (int, float))
        and 0 <= time.time() - state["checked_at"] < ${var.configuration.refresh_seconds}
        and request.user.ak_groups.filter(name=${jsonencode(var.configuration.group_name)}).exists()
    )
  EOT

  nonmember_expression = <<-EOT
    import time
    state = request.user.attributes.get(${jsonencode(local.attribute_key)}, {})
    checked_at = state.get("checked_at") if isinstance(state, dict) else None
    return not (
        isinstance(state, dict)
        and state.get("member") is True
        and isinstance(checked_at, (int, float))
        and 0 <= time.time() - checked_at < ${var.configuration.refresh_seconds}
        and request.user.ak_groups.filter(name=${jsonencode(var.configuration.group_name)}).exists()
    )
  EOT

  application_expression = join("\n", [<<-EOT
    # Application bindings run before the authorization flow can refresh SAML membership.
    http_request = request.http_request
    if (
        http_request is not None
        and http_request.path == "/application/o/authorize/"
        and request.context.get("oauth_grant_type") == "authorization_code"
    ):
        return True
    if request.context.get("oauth_grant_type") in ("client_credentials", "password", "refresh_token"):
        return False
  EOT
  , local.membership_expression])

  expiry_expression = <<-EOT
    state = token.user.attributes.get(${jsonencode(local.attribute_key)}, {})
    checked_at = state.get("checked_at") if isinstance(state, dict) else None
    if not isinstance(state, dict) or state.get("member") is not True or not isinstance(checked_at, (int, float)):
        return {"exp": 0}
    return {"exp": min(int(token.expires.timestamp()), int(checked_at) + ${var.configuration.refresh_seconds})}
  EOT

  source_expression = <<-EOT
    import time
    email = properties.get("email")
    if not isinstance(email, str):
        raise ValueError("Google SAML must provide exactly one email attribute")
    email = email.strip().lower()
    if email.count("@") != 1 or email.rsplit("@", 1)[-1] != ${jsonencode(lower(var.configuration.email_domain))}:
        raise ValueError("Google SAML email is outside the trusted domain")
    if http_request.user.is_authenticated and http_request.user.email.lower() != email:
        raise ValueError("Google SAML identity must match the signed-in Authentik user")
    asserted = properties.get(${jsonencode(var.configuration.group_attribute)}, [])
    if isinstance(asserted, str):
        asserted = [asserted]
    if not isinstance(asserted, list) or not all(isinstance(group, str) for group in asserted):
        raise ValueError("Google SAML group attribute must contain strings")
    member = ${jsonencode(var.configuration.google_group)} in asserted
    # Source mappings merge lists, so clear raw groups before returning the allowlisted group.
    properties["groups"] = []
    return {
        "username": email,
        "email": email,
        "groups": [${jsonencode(var.configuration.group_name)}] if member else [],
        "attributes": {
            ${jsonencode(local.attribute_key)}: {"member": member, "checked_at": time.time()},
        },
    }
  EOT
}
