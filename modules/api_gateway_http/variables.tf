variable "lambda_integrations" {
  type = map(object({
    invoke_arn    = string
    function_name = string
    route_prefix  = string
  }))
}
