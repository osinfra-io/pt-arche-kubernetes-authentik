# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  access_token_validity = "seconds=${var.configuration.refresh_seconds - 1}"
  application_name      = "Agentgateway administrators"
  attribute_key         = "${var.configuration.slug}-membership"
  source_acs_url        = "${trimsuffix(var.authentik_url, "/")}/source/saml/${var.configuration.slug}/acs/"
  source_entity_id      = "${trimsuffix(var.authentik_url, "/")}/source/saml/${var.configuration.slug}/metadata/"
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
    from datetime import datetime
    import time
    ns = "{urn:oasis:names:tc:SAML:2.0:assertion}"
    now = time.time()
    def timestamp(value):
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            raise ValueError("Google SAML timestamps must include a timezone")
        return parsed.timestamp()
    if (
        len(root.findall(ns + "Assertion")) != 1
        or root.findall(ns + "Assertion")[0] != assertion
        or root.findtext(ns + "Issuer") != ${jsonencode(var.configuration.idp_entity_id)}
        or assertion.findtext(ns + "Issuer") != ${jsonencode(var.configuration.idp_entity_id)}
        or root.get("Destination") != ${jsonencode(local.source_acs_url)}
        or not root.get("InResponseTo")
    ):
        raise ValueError("Google SAML response must target this source and trusted issuer")
    restrictions = assertion.findall(ns + "Conditions/" + ns + "AudienceRestriction")
    if not restrictions or not all(
        any(audience.text == ${jsonencode(local.source_entity_id)} for audience in restriction.findall(ns + "Audience"))
        for restriction in restrictions
    ):
        raise ValueError("Google SAML audience must match this environment's Entity ID")
    conditions = assertion.find(ns + "Conditions")
    if timestamp(conditions.get("NotOnOrAfter", "")) <= now:
        raise ValueError("Google SAML assertion has expired")
    confirmations = assertion.findall(ns + "Subject/" + ns + "SubjectConfirmation")
    valid_confirmation = False
    for confirmation in confirmations:
        data = confirmation.find(ns + "SubjectConfirmationData")
        if (
            confirmation.get("Method") == "urn:oasis:names:tc:SAML:2.0:cm:bearer"
            and data is not None
            and data.get("Recipient") == ${jsonencode(local.source_acs_url)}
            and data.get("InResponseTo") == root.get("InResponseTo")
            and timestamp(data.get("NotOnOrAfter", "")) > now
        ):
            valid_confirmation = True
    if not valid_confirmation:
        raise ValueError("Google SAML bearer confirmation must match this request and ACS")
    checked_at = timestamp(assertion.get("IssueInstant", ""))
    if checked_at > now + 60 or now - checked_at >= ${var.configuration.refresh_seconds}:
        raise ValueError("Google SAML membership assertion is outside the freshness bound")
    checked_at = min(now, checked_at)
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
            ${jsonencode(local.attribute_key)}: {"member": member, "checked_at": checked_at},
        },
    }
  EOT
}
