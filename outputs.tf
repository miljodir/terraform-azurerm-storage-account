output "storage_account" {
  description = "Output from all values for the created storage account."
  value       = azurerm_storage_account.account
}

output "private_endpoints" {
  value       = azurerm_private_endpoint.pe
  description = "Outputs private endpoints created for the storage account."
}
