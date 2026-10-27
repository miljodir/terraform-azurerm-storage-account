[![Changelog](https://img.shields.io/badge/changelog-release-green.svg)](https://github.com/miljodir/terraform-azurerm-storage-account/wiki/main#changelog)
[![TF Registry](https://img.shields.io/badge/terraform-registry-blue.svg)](https://registry.terraform.io/modules/miljodir/storage-account/azurerm/)

# Storage account
This module deploys a storage account with a private endpoint and DNS which can be in another subscription.
The private dns zone must already exist and permissions required (e.g. Private DNS Zone Contributor) is required to add records.

If `storage_account_name` is not specified, a random name including a `random_string` will be generated as the storage account name.

## Private Azure Files accounts

The module supports `FileStorage` accounts with Azure Files retention and SMB
settings through the nullable `share_properties` object. `retention_policy.days`
is required when that nested object is supplied. The `smb` object accepts optional
sets of strings for `versions`, `authentication_types`,
`kerberos_ticket_encryption_type`, and `channel_encryption_type`, plus optional
`multichannel_enabled`. Omitted nested settings use provider defaults; a null
`share_properties` (the default) emits no share properties block. Blob settings
are unchanged and are not emitted for `FileStorage`.

Use the existing `subnet_id` input for the private endpoint subnet. The optional
`private_dns_zone_ids` map accepts lists of existing zone ARM IDs keyed by private
endpoint subresource. Its default `{}` and empty lists create no DNS zone groups.
The existing endpoint lifecycle ignores DNS zone group changes: these inputs
configure newly created endpoints, but will not reconcile DNS group changes on
existing endpoints. Existing central DNS/policy ownership is preserved.

For private accounts, set **both** `allow_known_public_ips = false` and
`public_network_access_enabled = false`. The nullable `allow_known_public_ips`
input defaults to the existing inference: `d-*` resource groups enable public
access and known IP rules. Explicit `false` disables that override, known IP
lookup, and known IP rules even for `d-*` groups; explicit `true` enables them in
any resource group. It does not remove caller-supplied network rules.

```hcl
module "files" {
  source  = "miljodir/storage-account/azurerm"
  version = "~> 1.0"

  storage_account_name = "examplefilesaccount"
  resource_group_name = "d-example"
  location            = "norwayeast"
  account_kind        = "FileStorage"
  sku_name            = "Premium_ZRS"

  subnet_id         = "/subscriptions/<subscription-id>/resourceGroups/<network-rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>"
  private_endpoints = ["file"]
  private_dns_zone_ids = {
    file = ["/subscriptions/<subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"]
  }

  public_network_access_enabled = false
  allow_known_public_ips        = false
  azure_files_authentication = {
    directory_type = "AADKERB"
  }
  share_properties = {
    retention_policy = {
      days = 7
    }
    smb = {
      versions                        = ["SMB3.0", "SMB3.1.1"]
      authentication_types            = ["Kerberos"]
      kerberos_ticket_encryption_type = ["AES-256"]
      channel_encryption_type         = ["AES-128-GCM", "AES-256-GCM"]
      multichannel_enabled            = true
    }
  }
}
```

### Compatibility and validation

The example requires a module release containing these inputs. Published version
`1.11.1` does not contain them; `~> 1.0` cannot consume this change until a new
compatible release is published. No release version is prescribed here.

Existing callers retain their input defaults and output shapes:
`storage_account` is the complete storage account resource object and
`private_endpoints` is the map of endpoint resource objects keyed by subresource.
The intentional replication bug fix now honors `Premium_ZRS` instead of silently
creating `Premium_LRS`. Existing callers using `Premium_ZRS` must review the plan
for replication changes and Azure migration constraints.

Terraform `>= 1.7, < 2.0` is required because the existing `removed` block requires
1.7. Existing copy scope (`AAD`), Azure Files authentication, local user behavior,
and network rule defaults (`Deny`, `None`, no IP/subnet exceptions) are unchanged.
No locks or `prevent_destroy` are added.

The PR workflow runs static HCL source checks, not a Terraform plan. Terraform
initialization downloads the existing internal `cp-shared` module over SSH even
when its count is zero. Initialization and plan validation require an existing
authorized cross-repository CI credential/SSH setup; the default `GITHUB_TOKEN`
is insufficient. No credentials or persistent secrets are added by this change.
