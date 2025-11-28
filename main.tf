locals {
  storage_account_name           = var.storage_account_name != null ? var.storage_account_name : local.generated_storage_account_name
  generated_storage_account_name = var.storage_account_name == null ? "${local.storage_prefix}${var.purpose}${local.unique}" : ""
  storage_prefix                 = replace(var.resource_group_name, "-", "")

  unique                        = var.unique == null ? try(random_string.unique[0].result, null) : var.unique
  account_tier                  = split("_", var.sku_name)[0]
  account_replication_type      = (local.account_tier == "Premium" ? "LRS" : split("_", var.sku_name)[1])
  public_network_access_enabled = local.allow_known_pips ? true : var.public_network_access_enabled ? true : false
  allow_known_pips              = split("-", var.resource_group_name)[0] == "d" ? true : false
}

module "network_vars" {
  # private module used for public IP whitelisting
  count  = local.public_network_access_enabled == true ? 1 : 0
  source = "git@github.com:miljodir/cp-shared.git//modules/public_nw_ips?ref=public_nw_ips/v1"
}

resource "random_string" "unique" {
  count   = var.unique == null && var.storage_account_name == null ? 1 : 0
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_storage_account" "account" {
  resource_group_name               = var.resource_group_name
  name                              = local.storage_account_name
  location                          = var.location
  account_tier                      = local.account_tier
  account_replication_type          = local.account_replication_type
  provisioned_billing_model_version = var.provisioned_billing_model_version
  shared_access_key_enabled         = var.shared_access_key_enabled
  is_hns_enabled                    = var.is_hns_enabled
  min_tls_version                   = var.min_tls_version
  account_kind                      = var.account_kind
  public_network_access_enabled     = local.public_network_access_enabled
  allow_nested_items_to_be_public   = var.allow_nested_items_to_be_public
  nfsv3_enabled                     = var.nfsv3_enabled
  access_tier                       = var.access_tier
  https_traffic_only_enabled        = var.https_only
  local_user_enabled                = var.sftp_enabled && var.is_hns_enabled
  sftp_enabled                      = var.sftp_enabled

  allowed_copy_scope               = var.allowed_copy_scope != null ? var.allowed_copy_scope : null
  cross_tenant_replication_enabled = var.cross_tenant_replication_enabled

  network_rules {
    default_action             = var.network_rules.default_action != null ? var.network_rules.default_action : "Deny"
    bypass                     = var.network_rules.bypass != null ? var.network_rules.bypass : ["None"]
    ip_rules                   = local.allow_known_pips ? concat(values(module.network_vars[0].known_public_ips), var.network_rules.ip_rules) : var.network_rules.ip_rules
    virtual_network_subnet_ids = var.network_rules.subnet_ids != null ? var.network_rules.subnet_ids : []

    dynamic "private_link_access" {
      for_each = var.network_rules.private_link_access
      content {
        endpoint_resource_id = private_link_access.value.endpoint_resource_id
        endpoint_tenant_id   = private_link_access.value.endpoint_tenant_id
      }
    }
  }

  dynamic "blob_properties" {
    for_each = var.account_kind == "FileStorage" ? [] : ["blob_properties"]
    content {
      dynamic "delete_retention_policy" {
        for_each = var.enable_soft_delete ? ["delete_retention_policy"] : []
        content {
          days = var.blob_soft_delete_retention_days
        }
      }

      dynamic "container_delete_retention_policy" {
        for_each = var.enable_soft_delete ? ["container_delete_retention_policy"] : []
        content {
          days = var.container_soft_delete_retention_days
        }
      }

      dynamic "restore_policy" {
        for_each = var.enable_restore_policy ? ["restore_policy"] : []
        content {
          days = var.restore_policy_days
        }

      }

      versioning_enabled            = var.blob_properties == null ? var.enable_versioning : var.blob_properties.versioning_enabled
      last_access_time_enabled      = var.blob_properties == null ? var.enable_versioning : var.blob_properties.last_access_time_enabled
      change_feed_enabled           = var.blob_properties == null ? var.enable_versioning : var.blob_properties.change_feed_enabled
      change_feed_retention_in_days = var.blob_properties == null ? null : var.blob_properties.change_feed_retention_in_days
    }
  }

  dynamic "azure_files_authentication" {
    for_each = var.azure_files_authentication == null ? [] : [
      var.azure_files_authentication
    ]
    content {
      directory_type = azure_files_authentication.value.directory_type

      dynamic "active_directory" {
        for_each = azure_files_authentication.value.active_directory == null ? [] : [
          azure_files_authentication.value.active_directory
        ]
        content {
          domain_guid         = active_directory.value.domain_guid
          domain_name         = active_directory.value.domain_name
          domain_sid          = azure_files_authentication.value.directory_type == "AD" ? active_directory.value.domain_sid : null
          forest_name         = azure_files_authentication.value.directory_type == "AD" ? active_directory.value.forest_name : null
          netbios_domain_name = azure_files_authentication.value.directory_type == "AD" ? active_directory.value.netbios_domain_name : null
          storage_sid         = azure_files_authentication.value.directory_type == "AD" ? active_directory.value.storage_sid : null
        }
      }
    }
  }

  dynamic "static_website" {
    for_each = var.static_website != null ? ["true"] : []
    content {
      index_document     = var.static_website.index_document
      error_404_document = var.static_website.error_404_document
    }
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

  lifecycle {
    # Avoid recreation of the private endpoint due to moving to central module
    ignore_changes = [
      private_service_connection[0].name, name,
      private_dns_zone_group,
    ]
  }
}

removed {
  from = azurerm_private_dns_a_record.pe_dns
  lifecycle {
    destroy = false
  }
}
