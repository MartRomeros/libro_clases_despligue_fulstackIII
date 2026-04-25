variable "vpc_id" { type = string }
variable "private_subnets" { type = list(string) }
variable "security_group_id" { type = string }
variable "db_host" { type = string }
variable "db_user" { type = string }
variable "db_password" { type = string }
variable "db_name" { type = string }
variable "jwt_secret" { type = string }
variable "frontend_url" { type = string }
variable "image_uri" { type = string }

# Usamos el rol preexistente de Academy
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_lambda_function" "ms_auth" {
  function_name = "ms-auth-function"
  role          = data.aws_iam_role.lab_role.arn

  package_type = "Image"
  image_uri    = var.image_uri

  # AJUSTES PARA EVITAR ERROR 500 (Cold start y DB connection)
  timeout     = 30
  memory_size = 512

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      DB_USER      = var.db_user
      DB_PASSWORD  = var.db_password
      DB_HOST      = var.db_host
      DB_PORT      = "5432"
      DB_DATABASE  = var.db_name
      JWT_SECRET   = var.jwt_secret
      FRONTEND_URL = var.frontend_url
    }
  }
}

# Gestionar logs de CloudWatch
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/ms-auth-function"
  retention_in_days = 7
}

# API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "ms_auth_api" {
  name          = "ms-auth-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["*"]
    allow_headers = ["*"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.ms_auth_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.ms_auth_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ms_auth.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.ms_auth_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ms_auth.function_name
  principal     = "apigateway.amazonaws.com"

}

output "api_url" {
  value = aws_apigatewayv2_api.ms_auth_api.api_endpoint
}
