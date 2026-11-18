variable "nom_app_demo" {
  type    = string
  default = "quiz-demo"
}

resource "azurerm_container_app" "demo" {
  name                         = var.nom_app_demo
  resource_group_name          = var.infrastructure.resource_group_name
  container_app_environment_id = var.infrastructure.container_app_environment_id
  workload_profile_name        = "Consumption"
  revision_mode                = "Single"

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "demo"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

output "url_demo" {
  value = "https://${azurerm_container_app.demo.ingress[0].fqdn}"
}