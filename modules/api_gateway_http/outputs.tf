output "http_api_id" {
  description = "HTTP API identifier"
  value       = aws_apigatewayv2_api.api-gw.id
}

output "execution_arn" {
  description = "Execution ARN for the HTTP API"
  value       = aws_apigatewayv2_api.api-gw.execution_arn
}

output "invoke_url" {
  description = "Base invoke URL for the deployed HTTP API stage"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.api-gw.api_endpoint
}


output "service_endpoints" {
  value = {
    for name, cfg in var.lambda_integrations :
    name => "${aws_apigatewayv2_api.api-gw.api_endpoint}/${cfg.route_prefix}"
  }
}
