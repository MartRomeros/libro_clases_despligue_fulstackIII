# API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "api-gw" {
  name          = "api-gw"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["*"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api-gw.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  for_each = var.lambda_integrations

  api_id                 = aws_apigatewayv2_api.api-gw.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_routes" {
  for_each = var.lambda_integrations

  api_id    = aws_apigatewayv2_api.api-gw.id
  route_key = "ANY /${each.value.route_prefix}/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration[each.key].id}"
}

resource "aws_lambda_permission" "api_gw" {
  for_each = var.lambda_integrations

  statement_id  = "AllowExecutionFromAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
}
