output "ecr_name" {

  description = "nombre del ecr creado en este backend"
  value       = module.ecr_colegio.repository_name
}

output "ecr_url" {

  description = "url del ecr"
  value       = module.ecr_colegio.repository_url
}