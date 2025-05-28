
provider "azurerm" {
  features {}
  subscription_id = "260ccb84-6743-47cd-b2e9-07eee3c8a101"
}

data "azurerm_resource_group" "main" {
  name = "url-shortener-rg"
}

data "azurerm_key_vault" "kv" {
  name                = "urlshortenerkv001"
  resource_group_name = "url-shortener-rg"
}

data "azurerm_user_assigned_identity" "backend" {
  name                = "urlshortener-backend-identity"
  resource_group_name = "url-shortener-rg"
}

data "azurerm_container_registry" "acr" {
  name                = "urlshorteneracr001"
  resource_group_name = "url-shortener-rg"
}

data "azurerm_container_app_environment" "env" {
  name                = "urlshortener-env"
  resource_group_name = "url-shortener-rg"
}

data "azurerm_key_vault_secret" "uri" {
  name         = "cosmos-uri"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "key" {
  name         = "cosmos-key"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "db" {
  name         = "cosmos-db"
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "azurerm_key_vault_secret" "container" {
  name         = "cosmos-container"
  key_vault_id = data.azurerm_key_vault.kv.id
}

# -----------------------------
# Backend App
# -----------------------------

resource "azurerm_container_app" "backend" {
  name                         = "url-shortener-backend"
  container_app_environment_id = data.azurerm_container_app_environment.env.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.backend.id]
  }
  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = data.azurerm_user_assigned_identity.backend.id
  }
  secret {
    name  = "cosmos-uri"
    value = data.azurerm_key_vault_secret.uri.value
  }
  secret {
    name  = "cosmos-key"
    value = data.azurerm_key_vault_secret.key.value
  }
  secret {
    name  = "cosmos-db"
    value = data.azurerm_key_vault_secret.db.value
  }
  secret {
    name  = "cosmos-container"
    value = data.azurerm_key_vault_secret.container.value
  }
  template {
    container {
      name   = "backend"
      image  = "${data.azurerm_container_registry.acr.login_server}/url-shortener-backend:latest"
      cpu    = 0.5
      memory = "1Gi"
      env {
        name        = "COSMOS_URI"
        secret_name = "cosmos-uri"
      }
      env {
        name        = "COSMOS_KEY"
        secret_name = "cosmos-key"
      }
      env {
        name        = "COSMOS_DB"
        secret_name = "cosmos-db"
      }
      env {
        name        = "COSMOS_CONTAINER"
        secret_name = "cosmos-container"
      }
    }
  }
  ingress {
    external_enabled = false
    target_port      = 8000
    exposed_port     = 8000
    transport        = "tcp"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# -----------------------------
# Frontend App (public)
# -----------------------------
resource "azurerm_container_app" "frontend" {
  name                         = "url-shortener-frontend"
  container_app_environment_id = data.azurerm_container_app_environment.env.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.backend.id]
  }
  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = data.azurerm_user_assigned_identity.backend.id
  }
  template {
    container {
      name   = "frontend"
      image  = "${data.azurerm_container_registry.acr.login_server}/url-shortener-frontend:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }
  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
