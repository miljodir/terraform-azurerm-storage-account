mock_provider "azurerm" {
  # Generated mock IDs are random strings; resources that parse IDs need a real-looking one.
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/p-test-rg/providers/Microsoft.Storage/storageAccounts/ptestrgsaabc123"
    }
  }
}

mock_provider "random" {}

# The internal public IP module is replaced with documentation-range addresses.
override_module {
  target = module.network_vars
  outputs = {
    known_public_ips = {
      office = "192.0.2.10"
      vpn    = "198.51.100.20"
    }
  }
}

variables {
  resource_group_name = "p-test-rg"
  unique              = "abc123"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-pe"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = azurerm_storage_account.account.name == "ptestrgsaabc123"
    error_message = "Name should be '<resource group without dashes><purpose><unique>'."
  }

  assert {
    condition     = azurerm_storage_account.account.account_tier == "Standard" && azurerm_storage_account.account.account_replication_type == "RAGRS"
    error_message = "Default SKU Standard_RAGRS should split into tier and replication type."
  }

  assert {
    condition     = azurerm_storage_account.account.shared_access_key_enabled == false
    error_message = "Shared access keys should be disabled by default."
  }

  assert {
    condition     = azurerm_storage_account.account.min_tls_version == "TLS1_2"
    error_message = "Minimum TLS version should default to TLS1_2."
  }

  assert {
    condition     = azurerm_storage_account.account.https_traffic_only_enabled == true
    error_message = "HTTPS-only should be enabled by default."
  }

  assert {
    condition     = azurerm_storage_account.account.allow_nested_items_to_be_public == false
    error_message = "Nested items must not be public by default."
  }

  assert {
    condition     = azurerm_storage_account.account.allowed_copy_scope == "AAD"
    error_message = "Copy scope should default to AAD."
  }

  assert {
    condition     = azurerm_storage_account.account.cross_tenant_replication_enabled == false
    error_message = "Cross tenant replication should be disabled by default."
  }

  assert {
    condition     = azurerm_storage_account.account.local_user_enabled == false && azurerm_storage_account.account.sftp_enabled == false
    error_message = "Local users and SFTP should be disabled by default."
  }

  assert {
    condition     = azurerm_storage_account.account.network_rules[0].default_action == "Deny"
    error_message = "Network rules should deny by default."
  }

  assert {
    condition     = azurerm_storage_account.account.network_rules[0].bypass == toset(["None"])
    error_message = "Network rule bypass should default to None."
  }

  assert {
    condition     = length(azurerm_storage_account.account.network_rules[0].ip_rules) == 0
    error_message = "No IP rules should be added outside development resource groups."
  }

  assert {
    condition     = length(module.network_vars) == 0
    error_message = "Known public IP lookup should only be used in development."
  }

  assert {
    condition     = azurerm_storage_account.account.blob_properties[0].delete_retention_policy[0].days == 7
    error_message = "Blob soft delete should be enabled for 7 days by default."
  }

  assert {
    condition     = azurerm_storage_account.account.blob_properties[0].container_delete_retention_policy[0].days == 7
    error_message = "Container soft delete should be enabled for 7 days by default."
  }

  assert {
    condition     = length(azurerm_storage_account.account.blob_properties[0].cors_rule) == 0
    error_message = "No CORS rules should be configured by default."
  }

  assert {
    condition     = length(azurerm_storage_account.account.share_properties) == 0
    error_message = "Share properties should be unmanaged by default."
  }

  assert {
    condition     = length(azurerm_private_endpoint.pe) == 0 && length(azurerm_advanced_threat_protection.atp) == 0 && length(azurerm_storage_account_static_website.this) == 0
    error_message = "Optional resources should not be created by default."
  }

  assert {
    condition     = length(random_string.unique) == 0
    error_message = "No random suffix should be generated when unique is given."
  }
}

run "generated_unique_suffix" {
  command = apply

  variables {
    unique = null
  }

  assert {
    condition     = length(random_string.unique) == 1
    error_message = "A random suffix should be generated when neither unique nor storage_account_name is given."
  }

  assert {
    condition     = azurerm_storage_account.account.name == "ptestrgsa${random_string.unique[0].result}"
    error_message = "Generated name should use the random suffix."
  }
}

run "explicit_name" {
  command = plan

  variables {
    unique               = null
    storage_account_name = "stexplicitname"
  }

  assert {
    condition     = azurerm_storage_account.account.name == "stexplicitname"
    error_message = "storage_account_name should override the generated name."
  }

  assert {
    condition     = length(random_string.unique) == 0
    error_message = "No random suffix should be generated with an explicit name."
  }
}

run "premium_file_storage" {
  command = plan

  variables {
    sku_name     = "Premium_ZRS"
    account_kind = "FileStorage"
    share_properties = {
      retention_policy = { days = 30 }
      smb = {
        versions                        = ["SMB3.1.1"]
        authentication_types            = ["Kerberos"]
        kerberos_ticket_encryption_type = ["AES-256"]
        channel_encryption_type         = ["AES-256-GCM"]
      }
    }
  }

  assert {
    condition     = azurerm_storage_account.account.account_tier == "Premium" && azurerm_storage_account.account.account_replication_type == "ZRS"
    error_message = "Premium_ZRS should split into Premium/ZRS."
  }

  assert {
    condition     = length(azurerm_storage_account.account.blob_properties) == 0
    error_message = "FileStorage accounts must not configure blob properties."
  }

  assert {
    condition     = azurerm_storage_account.account.share_properties[0].retention_policy[0].days == 30
    error_message = "Share retention should be configurable."
  }

  assert {
    condition     = azurerm_storage_account.account.share_properties[0].smb[0].versions == toset(["SMB3.1.1"])
    error_message = "SMB versions should be passed through."
  }
}

run "cors_rules" {
  command = plan

  variables {
    cors_rules = [
      {
        allowed_origins    = ["https://example.com"]
        allowed_methods    = ["GET", "HEAD"]
        allowed_headers    = ["*"]
        exposed_headers    = ["x-ms-meta-*"]
        max_age_in_seconds = 3600
      }
    ]
  }

  assert {
    condition     = length(azurerm_storage_account.account.blob_properties[0].cors_rule) == 1
    error_message = "One CORS rule should be configured."
  }

  assert {
    condition     = azurerm_storage_account.account.blob_properties[0].cors_rule[0].allowed_origins == tolist(["https://example.com"])
    error_message = "CORS origins should be passed through."
  }

  assert {
    condition     = azurerm_storage_account.account.blob_properties[0].cors_rule[0].max_age_in_seconds == 3600
    error_message = "CORS max age should be passed through."
  }
}

run "blob_properties_override_legacy_versioning" {
  command = plan

  variables {
    enable_versioning = false
    blob_properties = {
      versioning_enabled            = true
      change_feed_enabled           = true
      change_feed_retention_in_days = 14
      last_access_time_enabled      = false
    }
  }

  assert {
    condition     = azurerm_storage_account.account.blob_properties[0].versioning_enabled == true
    error_message = "blob_properties.versioning_enabled should take precedence."
  }

  assert {
    condition     = azurerm_storage_account.account.blob_properties[0].change_feed_retention_in_days == 14
    error_message = "Change feed retention should be passed through."
  }
}

run "soft_delete_can_be_disabled" {
  command = plan

  variables {
    enable_soft_delete = false
  }

  assert {
    condition     = length(azurerm_storage_account.account.blob_properties[0].delete_retention_policy) == 0
    error_message = "Blob soft delete should be removed when disabled."
  }
}

run "network_rules_allow_removes_block" {
  command = plan

  variables {
    network_rules = {
      default_action = "Allow"
    }
  }

  assert {
    condition     = length(azurerm_storage_account.account.network_rules) == 0
    error_message = "The network_rules block should be omitted when default_action is Allow."
  }
}

run "development_allows_known_public_ips" {
  command = plan

  variables {
    resource_group_name           = "d-test-rg"
    public_network_access_enabled = false
    network_rules = {
      ip_rules = ["203.0.113.5"]
    }
  }

  assert {
    condition     = azurerm_storage_account.account.public_network_access_enabled == true
    error_message = "Development resource groups should enable public access for known IPs."
  }

  assert {
    condition     = azurerm_storage_account.account.network_rules[0].ip_rules == toset(["192.0.2.10", "198.51.100.20", "203.0.113.5"])
    error_message = "Known public IPs should be merged with caller ip_rules."
  }
}

run "development_known_ips_can_be_opted_out" {
  command = plan

  variables {
    resource_group_name           = "d-test-rg"
    allow_known_public_ips        = false
    public_network_access_enabled = false
  }

  assert {
    condition     = azurerm_storage_account.account.public_network_access_enabled == false
    error_message = "allow_known_public_ips = false should keep public access disabled."
  }

  assert {
    condition     = length(module.network_vars) == 0
    error_message = "Known public IP lookup should not be used when opted out."
  }
}

run "private_endpoints" {
  command = apply

  variables {
    private_endpoints = ["blob", "file"]
    private_dns_zone_ids = {
      file = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"]
    }
  }

  assert {
    condition     = toset(keys(azurerm_private_endpoint.pe)) == toset(["blob", "file"])
    error_message = "One private endpoint per requested subresource should be created."
  }

  assert {
    condition     = azurerm_private_endpoint.pe["file"].name == "ptestrgsaabc123-file"
    error_message = "Private endpoint name should be '<account>-<subresource>'."
  }

  assert {
    condition     = azurerm_private_endpoint.pe["blob"].private_service_connection[0].subresource_names == tolist(["blob"])
    error_message = "Private endpoint should target its subresource."
  }

  assert {
    condition     = length(azurerm_private_endpoint.pe["file"].private_dns_zone_group) == 1
    error_message = "A DNS zone group should be created when zone IDs are given."
  }

  assert {
    condition     = length(azurerm_private_endpoint.pe["blob"].private_dns_zone_group) == 0
    error_message = "No DNS zone group should be created without zone IDs."
  }
}

run "optional_resources" {
  command = apply

  variables {
    enable_advanced_threat_protection = true
    static_website = {
      index_document = "index.html"
    }
  }

  assert {
    condition     = azurerm_advanced_threat_protection.atp[0].target_resource_id == azurerm_storage_account.account.id
    error_message = "Threat protection should target the storage account."
  }

  assert {
    condition     = azurerm_storage_account_static_website.this[0].index_document == "index.html"
    error_message = "Static website should be configured."
  }
}

run "sftp_enables_local_users_only_with_hns" {
  command = plan

  variables {
    is_hns_enabled = true
    sftp_enabled   = true
  }

  assert {
    condition     = azurerm_storage_account.account.local_user_enabled == true
    error_message = "Local users should be enabled for SFTP with hierarchical namespace."
  }
}

run "invalid_unique_is_rejected" {
  command = plan

  variables {
    unique = "abc"
  }

  expect_failures = [var.unique]
}

run "invalid_copy_scope_is_rejected" {
  command = plan

  variables {
    allowed_copy_scope = "Anything"
  }

  expect_failures = [var.allowed_copy_scope]
}

run "invalid_billing_model_is_rejected" {
  command = plan

  variables {
    provisioned_billing_model_version = "V1"
  }

  expect_failures = [var.provisioned_billing_model_version]
}
