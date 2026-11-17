variable "infrastructure" {
  description = "Groupe, adresse ACR, environnement et identité fournis par terraform/infra."
  type = object({
    resource_group_name          = string
    registry_login_server        = string
    container_app_environment_id = string
    pull_identity_id             = string
    frontend_app_name            = optional(string, "quiz-frontend")
    backend_app_name             = optional(string, "quiz-backend")
  })
  nullable = false
}

variable "image_digests" {
  description = "Identifiants des deux images déjà publiées dans ACR."
  type = object({
    backend  = string
    frontend = string
  })
  nullable = false

  validation {
    condition = alltrue([
      for digest in values(var.image_digests) : can(regex("^sha256:[a-f0-9]{64}$", digest))
    ])
    error_message = "Renseigne les deux digests ACR au format sha256 suivi de 64 caractères hexadécimaux."
  }
}

variable "min_replicas" {
  description = "Nombre minimum de conteneurs lancés par application."
  type        = number
  default     = 0
  nullable    = false

  validation {
    condition     = contains([0, 1, 2], var.min_replicas)
    error_message = "Le nombre minimum de réplicas doit être un entier de 0 à 2."
  }
}

variable "admin_username" {
  description = "Nom de connexion au panneau de gestion du quiz."
  type        = string
  default     = "admin"
  nullable    = false

  validation {
    condition     = trimspace(var.admin_username) != ""
    error_message = "Renseigne un nom de connexion admin."
  }
}

variable "admin_password" {
  description = "Mot de passe du panneau de gestion du quiz."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = trimspace(var.admin_password) != ""
    error_message = "Renseigne le mot de passe admin du quiz."
  }
}

variable "jwt_secret" {
  description = "Clé utilisée par le backend pour signer les jetons admin."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = trimspace(var.jwt_secret) != ""
    error_message = "Renseigne la clé de signature des jetons admin."
  }
}

variable "database_url" {
  description = "URL du PostgreSQL externe. Elle peut rester vide pour tester /health."
  type        = string
  default     = ""
  sensitive   = true
  nullable    = false
}

variable "resend_api_key" {
  description = "Clé API Resend pour envoyer les résultats par e-mail."
  type        = string
  default     = ""
  sensitive   = true
  nullable    = false
}

variable "from_email" {
  description = "Expéditeur autorisé dans le compte Resend."
  type        = string
  default     = ""
  nullable    = false
}
