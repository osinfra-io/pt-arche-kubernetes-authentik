# Local Values
# https://opentofu.org/docs/language/values/locals

# Redis is intentionally absent: modern Authentik (2025.10+) caches core state, sessions, the
# embedded outpost store, and WebSocket connections in PostgreSQL, so no Redis is deployed.
# https://docs.goauthentik.io/install-config/high-availability

# The Cloud SQL Auth Proxy runs as a sidecar in every server and worker pod and authenticates to
# Cloud SQL via Workload Identity, so Authentik reaches the private-IP, ENCRYPTED_ONLY instance over
# the pod loopback without the database being exposed on the mesh.
# https://cloud.google.com/sql/docs/postgres/connect-auth-proxy

locals {
  # The chart ships resources: {} for both the server and the worker, so every value here is the
  # module's own. Limits are omitted entirely when null rather than rendered as an empty map, and
  # each limit is independent, so memory can be capped without also capping CPU.
  resource_specs = {
    cloud_sql_proxy = {
      limits_cpu      = var.cloud_sql_proxy_resources_limits_cpu
      limits_memory   = var.cloud_sql_proxy_resources_limits_memory
      requests_cpu    = var.cloud_sql_proxy_resources_requests_cpu
      requests_memory = var.cloud_sql_proxy_resources_requests_memory
    }

    server = {
      limits_cpu      = var.server_resources_limits_cpu
      limits_memory   = var.server_resources_limits_memory
      requests_cpu    = var.server_resources_requests_cpu
      requests_memory = var.server_resources_requests_memory
    }

    worker = {
      limits_cpu      = var.worker_resources_limits_cpu
      limits_memory   = var.worker_resources_limits_memory
      requests_cpu    = var.worker_resources_requests_cpu
      requests_memory = var.worker_resources_requests_memory
    }
  }

  resource_limits = {
    for name, spec in local.resource_specs : name => {
      for key, value in {
        cpu    = spec.limits_cpu
        memory = spec.limits_memory
      } : key => value if value != null
    }
  }

  resources = {
    for name, spec in local.resource_specs : name => merge(
      {
        requests = {
          cpu    = spec.requests_cpu
          memory = spec.requests_memory
        }
      },
      length(local.resource_limits[name]) > 0 ? { limits = local.resource_limits[name] } : {}
    )
  }

  # The chart creates and annotates a service account whose name comes from the authentik.fullname
  # template, which resolves to "authentik" because the Helm release name matches the chart name.
  # The server and worker pods only adopt it when server.serviceAccountName and
  # worker.serviceAccountName are set; otherwise they fall back to the default service account, whose
  # missing Workload Identity annotation makes the Cloud SQL Auth Proxy authenticate as the node.
  service_account_name = "authentik"

  cloud_sql_proxy_container = {
    name  = "cloud-sql-proxy"
    image = var.cloud_sql_proxy_image

    args = [
      "--private-ip",
      "--structured-logs",
      "--port=${var.external_database_port}",
      var.cloud_sql_connection_name,
    ]

    resources = local.resources["cloud_sql_proxy"]

    securityContext = {
      runAsNonRoot = true
    }
  }

  helm_values = yamlencode({
    authentik = {
      postgresql = {
        host    = "127.0.0.1"
        name    = var.external_database_name
        port    = var.external_database_port
        sslmode = "disable"
        user    = var.external_database_user
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
      extraContainers = [local.cloud_sql_proxy_container]

      replicas = var.server_replicas

      resources = local.resources["server"]

      serviceAccountName = local.service_account_name
    }

    serviceAccount = {
      annotations = {
        "iam.gke.io/gcp-service-account" = var.google_service_account_email
      }
    }

    worker = {
      extraContainers = [local.cloud_sql_proxy_container]

      replicas = var.worker_replicas

      resources = local.resources["worker"]

      serviceAccountName = local.service_account_name
    }
  })
}
