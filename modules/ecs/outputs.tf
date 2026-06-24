output "cluster_name" {
  description = "Nombre del ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "cluster_id" {
  description = "ID del ECS cluster"
  value       = aws_ecs_cluster.this.id
}
