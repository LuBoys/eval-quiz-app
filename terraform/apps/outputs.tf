output "frontend_url" {
  description = "Adresse HTTPS automatique du quiz."
  value       = "https://${azurerm_container_app.frontend.ingress[0].fqdn}"
}

output "health_url" {
  description = "Adresse qui vérifie le backend en passant par Nginx."
  value       = "https://${azurerm_container_app.frontend.ingress[0].fqdn}/health"
}

output "frontend_dns" {
  description = "Valeurs à donner au gestionnaire DNS après attribution d’un sous-domaine."
  sensitive   = true
  value = {
    cname_target           = azurerm_container_app.frontend.ingress[0].fqdn
    verification_txt_value = azurerm_container_app.frontend.custom_domain_verification_id
  }
}
