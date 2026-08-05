# Test
# https://opentofu.org/docs/cli/commands/test

run "regional_config_live" {
  command = apply

  assert {
    condition     = output.issuer_url == "https://127.0.0.1:9443/application/o/gateway/"
    error_message = "The live fixture should produce the expected OIDC issuer URL."
  }

  assert {
    condition     = output.outpost_service_name == "authentik-server"
    error_message = "The live fixture should expose authentik-server as the embedded outpost service."
  }
}
