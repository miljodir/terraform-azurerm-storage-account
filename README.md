[![Changelog](https://img.shields.io/badge/changelog-release-green.svg)](https://github.com/miljodir/terraform-azurerm-storage-account/wiki/main#changelog)
[![TF Registry](https://img.shields.io/badge/terraform-registry-blue.svg)](https://registry.terraform.io/modules/miljodir/storage-account/azurerm/)

# Storage account
This module deploys a storage account with a private endpoint and DNS which can be in another subscription.
The private dns zone must already exist and permissions required (e.g. Private DNS Zone Contributor) is required to add records.

If `storage_account_name` is not specified, a random name including a `random_string` will be generated as the storage account name.
