output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_listener_arn" {
  description = "ARN del listener HTTP (se usa como integration_uri en el VPC Link de API Gateway)"
  value       = aws_lb_listener.main.arn
}

output "alb_target_group_arns" {
  description = "Mapa de service key → ARN del target group (usado por ECS para registrar tasks por IP)"
  value       = { for k, tg in aws_lb_target_group.services : k => tg.arn }
}
