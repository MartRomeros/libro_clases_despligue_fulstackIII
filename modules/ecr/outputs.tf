output "repository_url" {
  description = "URL del repositorio ECR creado"
  value       = aws_ecr_repository.repo.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio ECR creado"
  value       = aws_ecr_repository.repo.arn
}
