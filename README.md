# Storage account
This module deploys a storage account with a private endpoint and DNS which can be in another subscription.
The private dns zone must already exist and permissions required (e.g. Private DNS Zone Contributor) is required to add records.

If `storage_account_name` is not specified, a random name including a `random_string` will be generated as the storage account name.