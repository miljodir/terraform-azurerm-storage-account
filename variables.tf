variable "resource_group_name" {
  type        = string
  description = "Resource Group Name where resources should be placed."
}

variable "dns_resource_group_name" {
  type        = string
  description = "DNS Resource Group Name where resources should be placed."
  default     = "p-dns-pri"
}

variable "location" {
  type        = string
  description = "Location where resources should be placed."
  default     = "norwayeast"
}

variable "storage_account_name" {
  type        = string
  description = "Name of your storage account if you want explicit naming. Defaults to a combination of workloadname, prefix, and a random string."
  default     = null
}

variable "purpose" {
  type        = string
  description = "Purpose of your storage account."
  default     = "sa"
}

variable "subnet_id" {
  type        = string
  description = "Subnet resource Id for private endpoints."
  default     = null
}

variable "private_endpoints" {
  type        = list(any)
  description = "List of private endpoints that should be enabled. Supported values: blob, blob_secondary, table, table_secondary, queue, queue_secondary, file, file_secondary, web, web_secondary, dfs, dfs_secondary"
  default     = []
}

variable "unique" {
  type        = string
  description = "Provide a unique string if you want to use an already generated one."
  default     = null

  validation {
    condition     = length(var.unique == null ? "123456" : var.unique) == 6 #temp workaround. In the cases where var.unique is not set we want to "skip" verification. length() does not support null values
    error_message = "Unique string must be exactly 6 chars long."
  }
}

variable "enable_advanced_threat_protection" {
  type        = bool
  description = "Disable Azure Defender for Storage? Defaults to false."
  default     = false
}

variable "shared_access_key_enabled" {
  type        = bool
  description = "Enable or disable shared access key. Defaults to false, as this is somewhat of a security risk."
  default     = false
}

variable "is_hns_enabled" {
  type        = bool
  description = "Is Hierarchical Namespace enabled? This can be used with Azure Data Lake Storage Gen 2. Defaults to false."
  default     = false
}

variable "sku_name" {
  type        = string
  description = "The SKUs supported by Microsoft Azure Storage. Defaults to Standard_RAGRS Valid options are Premium_LRS, Premium_ZRS, Standard_GRS, Standard_GZRS, Standard_LRS, Standard_RAGRS, Standard_RAGZRS, Standard_ZRS."
  default     = "Standard_RAGRS"
}

variable "account_kind" {
  type        = string
  description = "The type of storage account. Defaults to StorageV2. Valid options are BlobStorage, BlockBlobStorage, FileStorage, Storage and StorageV2."
  default     = "StorageV2"
}

variable "min_tls_version" {
  type        = string
  description = "Minimum TLS version. Defaults to 1.2 as the older ones are considered insecure."
  default     = "TLS1_2"
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Is public network access enabled? Defaults to true."
  default     = true # TODO - default to false when v3 is released
}

variable "allow_nested_items_to_be_public" {
  type        = bool
  description = "Allow nested items to be public? Defaults to false."
  default     = false
}

variable "network_rules" {
  description = "Network rules restricing access to the storage account."
  type = object({
    default_action      = optional(string, "Deny")
    bypass              = optional(list(string), ["None"]),
    ip_rules            = optional(list(string), []),
    subnet_ids          = optional(list(string)),
    private_link_access = optional(list(object({ endpoint_resource_id = string, endpoint_tenant_id = string })), [])
  })
  default = {
    default_action      = "Deny"
    bypass              = ["None"]
    ip_rules            = []
    subnet_ids          = []
    private_link_access = []
  }
}

variable "blob_soft_delete_retention_days" {
  type        = number
  description = "Specifies the number of days that the blob should be retained, between 1 and 365 days. Defaults to 7"
  default     = 7
}

variable "container_soft_delete_retention_days" {
  type        = number
  description = "Specifies the number of days that the container should be retained, between 1 and 365 days. Defaults to 7"
  default     = 7
}

variable "enable_restore_policy" {
  type        = bool
  description = "Is restore policy enabled? Defaults to false."
  default     = false

}

variable "restore_policy_days" {
  type        = number
  description = "Specifies the number of days that the restore policy should be retained, between 1 and 365 days. Defaults to 7"
  default     = 30
}

variable "blob_properties" {
  type = object({
    versioning_enabled            = optional(bool)
    change_feed_enabled           = optional(bool)
    change_feed_retention_in_days = optional(number)
    last_access_time_enabled      = optional(bool)
  })
  default     = null
  description = "Specifies blob service properties."
}

# todo: remove in favour of blob_properties variable in next major version
variable "enable_versioning" {
  type        = bool
  description = "Is versioning enabled? Default to false."
  default     = false
}

# This one is unused in the module
variable "last_access_time_enabled" {
  type        = bool
  description = "Is the last access time based tracking enabled? Default to false."
  default     = false
}

# This one is unused in the module
variable "change_feed_enabled" {
  type        = bool
  description = "Is the blob service properties for change feed events enabled? Defaults to false."
  default     = false
}

variable "nfsv3_enabled" {
  type        = bool
  description = "Is the NFS protocol enabled for the Blob service? Defaults to false."
  default     = false
}

variable "access_tier" {
  type        = string
  description = "The access tier for the storage account. Defaults to Hot."
  default     = "Hot"
}

variable "https_only" {
  type        = bool
  description = "Is HTTPS only enabled? Defaults to true. Must be false for using NFS protocol towards Azure Files."
  default     = true
}

variable "azure_files_authentication" {
  type = object({
    directory_type = string
    active_directory = optional(object({
      domain_guid         = optional(string, null)
      domain_name         = optional(string, null)
      domain_sid          = optional(string, " ")
      forest_name         = optional(string, " ")
      netbios_domain_name = optional(string, " ")
      storage_sid         = optional(string, " ")
    }))
  })
  default     = null
  description = <<-EOT
 - `directory_type` - (Required) Specifies the directory service used. Possible values are `AADDS`, `AD` and `AADKERB`.

 ---
 `active_directory` block supports the following:
 - `domain_guid` - (Required) Specifies the domain GUID.
 - `domain_name` - (Required) Specifies the primary domain that the AD DNS server is authoritative for.
 - `domain_sid` - (Required) Specifies the security identifier (SID).
 - `forest_name` - (Required) Specifies the Active Directory forest.
 - `netbios_domain_name` - (Required) Specifies the NetBIOS domain name.
 - `storage_sid` - (Required) Specifies the security identifier (SID) for Azure Storage.
EOT
}

variable "sftp_enabled" {
  type        = bool
  description = "Is SFTP enabled? Defaults to false."
  default     = false
}

variable "allowed_copy_scope" {
  type        = string
  description = "Limit the copy scope of incoming data to the storage account. Defaults to AAD."
  default     = "AAD"
  validation {
    condition     = var.allowed_copy_scope == null || var.allowed_copy_scope == "AAD" || var.allowed_copy_scope == "PrivateLink"
    error_message = "allowed_copy_scope must be either AAD, PrivateLink or null."
  }
}

variable "cross_tenant_replication_enabled" {
  type        = bool
  description = "Is support for cross-tenant replication enabled? Defaults to false."
  default     = false
}

variable "static_website" {
  type = object({
    index_document     = optional(string)
    error_404_document = optional(string)
  })
  description = "Static website configuration."
  default     = null
}

variable "enable_soft_delete" {
  type        = bool
  default     = true
  description = "Enable or disable soft delete for blobs and containers."
}

variable "provisioned_billing_model_version" {
  type        = string
  description = "The provisioned billing model version of the storage account. Possible values are null and `V2`. Defaults to null."
  default     = null
  validation {
    condition     = var.provisioned_billing_model_version == null || var.provisioned_billing_model_version == "V2"
    error_message = "provisioned_billing_model_version must be either V1, V2 or null."
  }

}
