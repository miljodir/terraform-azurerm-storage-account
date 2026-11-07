# Test-only: the storage_account output contains access keys. Terraform requires
# root module outputs with sensitive values to be marked sensitive, which only
# matters when the module itself is the root module (as in terraform test).
output "storage_account" {
  sensitive = true
}
