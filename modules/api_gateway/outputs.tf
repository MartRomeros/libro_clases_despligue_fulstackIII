output "api_id" {
  description = "HTTP API ID"
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "Base API endpoint"
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "invoke_url" {
  description = "Invoke URL for the configured stage"
  value       = aws_apigatewayv2_stage.this.invoke_url
}

output "stage_name" {
  description = "Stage name in use"
  value       = aws_apigatewayv2_stage.this.name
}
