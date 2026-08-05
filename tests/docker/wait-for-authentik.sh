#!/usr/bin/env bash

set -euo pipefail

readonly API_BASE_URL="${AUTHENTIK_API_BASE_URL:-https://127.0.0.1:9443}"
readonly AUTHORIZATION_FLOW_SLUG="${AUTHENTIK_AUTHORIZATION_FLOW_SLUG:-default-provider-authorization-implicit-consent}"
readonly INVALIDATION_FLOW_SLUG="${AUTHENTIK_INVALIDATION_FLOW_SLUG:-default-provider-invalidation-flow}"
readonly TIMEOUT_SECONDS="${AUTHENTIK_HEALTHCHECK_TIMEOUT_SECONDS:-300}"
readonly INTERVAL_SECONDS=5

authentik_token="${AUTHENTIK_BOOTSTRAP_TOKEN:-}"
if [ -z "${authentik_token}" ] && [ -f "${AUTHENTIK_ENV_FILE:-tests/docker/.env}" ]; then
  authentik_token="$(
    grep '^AUTHENTIK_BOOTSTRAP_TOKEN=' "${AUTHENTIK_ENV_FILE:-tests/docker/.env}" | cut -d '=' -f 2- | sed 's/[[:space:]]*#.*$//' || true
  )"
fi

if [ -z "${authentik_token}" ]; then
  echo "AUTHENTIK_BOOTSTRAP_TOKEN is required for readiness checks." >&2
  exit 1
fi

elapsed_seconds=0

check_ready() {
  curl --fail --insecure --silent --show-error "${API_BASE_URL}/-/health/live/" >/dev/null &&
    curl --fail --insecure --silent --show-error -H "Authorization: Bearer ${authentik_token}" "${API_BASE_URL}/api/v3/flows/instances/?slug=${AUTHORIZATION_FLOW_SLUG}" | grep -F "\"${AUTHORIZATION_FLOW_SLUG}\"" >/dev/null &&
    curl --fail --insecure --silent --show-error -H "Authorization: Bearer ${authentik_token}" "${API_BASE_URL}/api/v3/flows/instances/?slug=${INVALIDATION_FLOW_SLUG}" | grep -F "\"${INVALIDATION_FLOW_SLUG}\"" >/dev/null &&
    curl --fail --insecure --silent --show-error -H "Authorization: Bearer ${authentik_token}" "${API_BASE_URL}/api/v3/propertymappings/provider/scope/?managed=goauthentik.io%2Fproviders%2Foauth2%2Fscope-email" | grep -F "goauthentik.io/providers/oauth2/scope-email" >/dev/null &&
    curl --fail --insecure --silent --show-error -H "Authorization: Bearer ${authentik_token}" "${API_BASE_URL}/api/v3/propertymappings/provider/scope/?managed=goauthentik.io%2Fproviders%2Foauth2%2Fscope-openid" | grep -F "goauthentik.io/providers/oauth2/scope-openid" >/dev/null &&
    curl --fail --insecure --silent --show-error -H "Authorization: Bearer ${authentik_token}" "${API_BASE_URL}/api/v3/propertymappings/provider/scope/?managed=goauthentik.io%2Fproviders%2Foauth2%2Fscope-profile" | grep -F "goauthentik.io/providers/oauth2/scope-profile" >/dev/null
}

until check_ready; do
  if [ "${elapsed_seconds}" -ge "${TIMEOUT_SECONDS}" ]; then
    echo "Timed out waiting for Authentik bootstrap readiness at ${API_BASE_URL}" >&2
    exit 1
  fi

  sleep "${INTERVAL_SECONDS}"
  elapsed_seconds=$((elapsed_seconds + INTERVAL_SECONDS))
done

echo "Authentik bootstrap readiness checks passed at ${API_BASE_URL}"

# Write the embedded outpost UUID to terraform.auto.tfvars so the import block
# in tests/docker/regional/config/main.tofu resolves correctly for this instance.
readonly TFVARS_FILE="${AUTHENTIK_TFVARS_FILE:-tests/docker/regional/config/terraform.auto.tfvars}"
embedded_outpost_id="$(
  curl --insecure --silent --show-error \
    -H "Authorization: Bearer ${authentik_token}" \
    "${API_BASE_URL}/api/v3/outposts/instances/?managed=goauthentik.io%2Foutposts%2Fembedded" |
    grep -o '"pk":"[^"]*"' | head -1 | cut -d'"' -f4
)"

if [ -z "${embedded_outpost_id}" ]; then
  echo "Could not resolve embedded outpost UUID from Authentik API" >&2
  exit 1
fi

cat > "${TFVARS_FILE}" <<EOF
embedded_outpost_id = "${embedded_outpost_id}"
EOF

echo "Wrote embedded outpost UUID ${embedded_outpost_id} to ${TFVARS_FILE}"
