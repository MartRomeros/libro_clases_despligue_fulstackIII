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
