output "account_ids" {
  description = "Mapa <pais>-<entorno> => account_id, para que cada environments/<pais>/<entorno> sepa en qué cuenta desplegar"
  value       = { for k, v in aws_organizations_account.workload : k => v.id }
}

output "shared_account_id" {
  description = "Account ID de la cuenta shared/tools (state backend, logging centralizado)"
  value       = aws_organizations_account.shared.id
}

output "organizational_units" {
  description = "OU id por país, útil para adjuntar SCPs más adelante"
  value       = { for k, v in aws_organizations_organizational_unit.pais : k => v.id }
}
