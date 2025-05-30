
provider "azurerm" {
  features {}
  subscription_id = "260ccb84-6743-47cd-b2e9-07eee3c8a101"
}

resource "azurerm_resource_group" "main" {
  name     = "url-shortener-rg"
  location = "australiaeast"
}

# -----------------------------
# Azure Container Registry
# -----------------------------
resource "azurerm_container_registry" "acr" {
  name                = "urlshorteneracr001"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_role_assignment" "acr_pull_current" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_client_config.current.object_id
}

# -----------------------------
# Cosmos DB
# -----------------------------
resource "azurerm_cosmosdb_account" "db" {
  name                = "urlshortenercosmos"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }
  capabilities {
    name = "EnableServerless"
  }
}

resource "azurerm_cosmosdb_sql_database" "db" {
  name                = "urlshortenerdb"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.db.name
}

resource "azurerm_cosmosdb_sql_container" "container" {
  name                = "urls"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.db.name
  database_name       = azurerm_cosmosdb_sql_database.db.name
  partition_key_paths = ["/id"]
}

# -----------------------------
# Key Vault
# -----------------------------
resource "azurerm_key_vault" "kv" {
  name                      = "urlshortenerkv001"
  location                  = azurerm_resource_group.main.location
  resource_group_name       = azurerm_resource_group.main.name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  sku_name                  = "standard"
  purge_protection_enabled  = false
  enable_rbac_authorization = true
}

resource "azurerm_role_assignment" "kv_current" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "uri" {
  name         = "cosmos-uri"
  value        = azurerm_cosmosdb_account.db.endpoint
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.kv_current]
}

resource "azurerm_key_vault_secret" "key" {
  name         = "cosmos-key"
  value        = azurerm_cosmosdb_account.db.primary_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.kv_current]
}

resource "azurerm_key_vault_secret" "db" {
  name         = "cosmos-db"
  value        = azurerm_cosmosdb_sql_database.db.name
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.kv_current]
}

resource "azurerm_key_vault_secret" "container" {
  name         = "cosmos-container"
  value        = azurerm_cosmosdb_sql_container.container.name
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_role_assignment.kv_current]
}

# -----------------------------
# Container Apps Environment
# -----------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_container_app_environment" "env" {
  name                = "urlshortener-env"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# -----------------------------
# Backend App Managed Identity
# -----------------------------
resource "azurerm_user_assigned_identity" "backend" {
  name                = "urlshortener-backend-identity"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "kv_backend_app" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}

resource "azurerm_role_assignment" "apps_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.backend.principal_id
}
