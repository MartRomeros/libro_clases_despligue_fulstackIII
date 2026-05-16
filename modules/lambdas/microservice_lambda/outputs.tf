output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "arn" {
  description = "Lambda ARN"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "Lambda invoke ARN"
  value       = aws_lambda_function.this.invoke_arn
}
