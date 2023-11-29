locals {
  storage_account_name           = var.storage_account_name != null ? var.storage_account_name : local.generated_storage_account_name
  generated_storage_account_name = var.storage_account_name == null ? "${local.storage_prefix}${var.purpose}${local.unique}" : ""
  storage_prefix                 = replace(var.resource_group_name, "-", "")
  unique                         = var.unique == null ? random_string.unique[0].result : var.unique

  account_tier             = (var.account_kind == "FileStorage" ? "Premium" : split("_", var.sku_name)[0])
  account_replication_type = (local.account_tier == "Premium" ? "LRS" : split("_", var.sku_name)[1])
}

resource "random_string" "unique" {
  count   = var.unique == null ? 1 : 0
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "account" {
  resource_group_name             = var.resource_group_name
  name                            = local.storage_account_name
  location                        = var.location
  account_tier                    = local.account_tier
  account_replication_type        = local.account_replication_type
  shared_access_key_enabled       = var.shared_access_key_enabled
  is_hns_enabled                  = var.is_hns_enabled
  min_tls_version                 = var.min_tls_version
  account_kind                    = var.account_kind
  public_network_access_enabled   = var.public_network_access_enabled
  allow_nested_items_to_be_public = var.allow_nested_items_to_be_public
  nfsv3_enabled                   = var.nfsv3_enabled
  access_tier                     = var.access_tier

  dynamic "network_rules" {
    for_each = var.network_rules != null ? ["true"] : []
    content {
      default_action             = var.network_rules.default_action != null ? var.network_rules.default_action : "Deny"
      bypass                     = var.network_rules.bypass != null ? var.network_rules.bypass : ["None"]
      ip_rules                   = var.network_rules.ip_rules != null ? var.network_rules.ip_rules : []
      virtual_network_subnet_ids = var.network_rules.subnet_ids != null ? var.network_rules.subnet_ids : []

      dynamic "private_link_access" {
        for_each = var.network_rules.private_link_access
        content {
          endpoint_resource_id = private_link_access.value.endpoint_resource_id
          endpoint_tenant_id   = private_link_access.value.endpoint_tenant_id
        }
      }
    }
  }

  blob_properties {
    delete_retention_policy {
      days = var.account_kind == "FileStorage" ? null : var.blob_soft_delete_retention_days
    }
    container_delete_retention_policy {
      days = var.account_kind == "FileStorage" ? null : var.container_soft_delete_retention_days
    }
    versioning_enabled       = var.account_kind == "FileStorage" ? null : var.enable_versioning
    last_access_time_enabled = var.account_kind == "FileStorage" ? null : var.last_access_time_enabled
    change_feed_enabled      = var.account_kind == "FileStorage" ? null : var.change_feed_enabled
  }
}

resource "azurerm_advanced_threat_protection" "atp" {
  count              = var.enable_advanced_threat_protection == true ? 1 : 0
  target_resource_id = azurerm_storage_account.account.id
  enabled            = var.enable_advanced_threat_protection
}

resource "azurerm_private_endpoint" "pe" {
  for_each            = toset(var.private_endpoints)
  location            = azurerm_storage_account.account.location
  name                = "${azurerm_storage_account.account.name}-${each.key}"
  resource_group_name = azurerm_storage_account.account.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = azurerm_storage_account.account.name
    private_connection_resource_id = azurerm_storage_account.account.id
    subresource_names              = [each.key]
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_a_record" "pe_dns" {
  for_each            = toset(var.private_endpoints)
  name                = azurerm_storage_account.account.name
  records             = [azurerm_private_endpoint.pe[each.key].private_service_connection[0].private_ip_address]
  resource_group_name = var.dns_resource_group_name
  ttl                 = 3600
  zone_name           = replace("privatelink.${each.key}.core.windows.net", "_secondary", "") #removes _secondary from zone name because private endpoint for eg. blob and blob_secondary is privatelink.blob.core.windows.net
  provider            = azurerm.p-dns
}
