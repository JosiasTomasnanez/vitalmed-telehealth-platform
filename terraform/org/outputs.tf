output "prod_account_ids" {
  description = "Mapa <pais> => account_id de la cuenta de producción de ese país"
  value       = { for k, v in aws_organizations_account.prod : k => v.id }
}

output "preprod_account_id" {
  description = "Account ID de la única cuenta de preproducción (general, no por país)"
  value       = aws_organizations_account.preprod.id
}

output "shared_account_id" {
  description = "Account ID de la cuenta shared/tools (state backend, logging centralizado)"
  value       = aws_organizations_account.shared.id
}

output "organizational_units" {
  description = "OU id por país, útil para adjuntar SCPs más adelante"
  value       = { for k, v in aws_organizations_organizational_unit.pais : k => v.id }
}
