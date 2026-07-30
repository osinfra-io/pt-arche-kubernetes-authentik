# Local Values
# https://opentofu.org/docs/language/values/locals

# Redis is intentionally absent: modern Authentik (2025.10+) caches core state, sessions, the
# embedded outpost store, and WebSocket connections in PostgreSQL, so no Redis is deployed.
# https://docs.goauthentik.io/install-config/high-availability

locals {
  helm_values = yamlencode({
    authentik = {
      postgresql = {
        host = var.external_database_host
        name = var.external_database_name
        port = var.external_database_port
        user = var.external_database_user
      }
    }

    global = {
      envFrom = [
        {
          secretRef = {
            name = var.existing_secret
          }
        }
      ]

      # When the namespace is mesh-injected under STRICT mTLS, hold the server and worker containers
      # until the Istio sidecar is ready so startup database connectivity is not attempted before the
      # proxy can carry it. https://istio.io/latest/docs/reference/config/istio.mesh.v1alpha1/#ProxyConfig
      podAnnotations = {
        "proxy.istio.io/config" = jsonencode({
          holdApplicationUntilProxyStarts = true
        })
      }
    }

    postgresql = {
      enabled = false
    }

    server = {
      replicas = var.server_replicas

      resources = {
        limits = {
          memory = var.server_resources_limits_memory
        }

        requests = {
          cpu    = var.server_resources_requests_cpu
          memory = var.server_resources_requests_memory
        }
      }
    }

    worker = {
      replicas = var.worker_replicas

      resources = {
        limits = {
          memory = var.worker_resources_limits_memory
        }

        requests = {
          cpu    = var.worker_resources_requests_cpu
          memory = var.worker_resources_requests_memory
        }
      }
    }
  })
}
