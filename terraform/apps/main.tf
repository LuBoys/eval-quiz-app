locals {
  backend_name  = "quiz-backend"
  backend_port  = 3007
  frontend_name = "quiz-frontend"
  frontend_port = 8080

  backend_secrets = merge(
    {
      ADMIN_PASSWORD = { name = "admin-password", value = var.admin_password }
      JWT_SECRET     = { name = "jwt-secret", value = var.jwt_secret }
    },
    trimspace(var.database_url) == "" ? {} : {
      DATABASE_URL = { name = "database-url", value = var.database_url }
    },
    trimspace(var.resend_api_key) == "" ? {} : {
      RESEND_API_KEY = { name = "resend-api-key", value = var.resend_api_key }
    }
  )
}

resource "azurerm_container_app" "backend" {
  name                         = local.backend_name
  resource_group_name          = var.infrastructure.resource_group_name
  container_app_environment_id = var.infrastructure.container_app_environment_id
  workload_profile_name        = "Consumption"
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.infrastructure.pull_identity_id]
  }

  registry {
    server   = var.infrastructure.registry_login_server
    identity = var.infrastructure.pull_identity_id
  }

  dynamic "secret" {
    for_each = local.backend_secrets

    content {
      name  = secret.value.name
      value = secret.value.value
    }
  }

  ingress {
    external_enabled           = false
    allow_insecure_connections = false
    target_port                = local.backend_port

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "backend"
      image  = "${var.infrastructure.registry_login_server}/${local.backend_name}@${var.image_digests.backend}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "ADMIN_USERNAME"
        value = var.admin_username
      }

      env {
        name  = "FROM_EMAIL"
        value = var.from_email
      }

      dynamic "env" {
        for_each = local.backend_secrets

        content {
          name        = env.key
          secret_name = env.value.name
        }
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = local.backend_port
        success_count_threshold = 1
      }
    }
  }

  lifecycle {
    # Le script Azure CLI gère l’image et la configuration du backend après sa création.
    ignore_changes = [secret, template[0].container[0].image, template[0].container[0].env]

    precondition {
      condition     = trimspace(var.resend_api_key) == "" || trimspace(var.from_email) != ""
      error_message = "Renseigne l’expéditeur from_email pour activer Resend."
    }
  }
}

resource "azurerm_container_app" "frontend" {
  name                         = local.frontend_name
  resource_group_name          = var.infrastructure.resource_group_name
  container_app_environment_id = var.infrastructure.container_app_environment_id
  workload_profile_name        = "Consumption"
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.infrastructure.pull_identity_id]
  }

  registry {
    server   = var.infrastructure.registry_login_server
    identity = var.infrastructure.pull_identity_id
  }

  ingress {
    external_enabled           = true
    allow_insecure_connections = false
    target_port                = local.frontend_port

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "frontend"
      image  = "${var.infrastructure.registry_login_server}/${local.frontend_name}@${var.image_digests.frontend}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "BACKEND_URL"
        value = "https://${azurerm_container_app.backend.ingress[0].fqdn}"
      }

      readiness_probe {
        transport               = "HTTP"
        path                    = "/"
        port                    = local.frontend_port
        success_count_threshold = 1
      }
    }
  }

  lifecycle {
    # Les livraisons Azure CLI continuent à choisir le digest déployé.
    ignore_changes = [template[0].container[0].image]
  }
}
