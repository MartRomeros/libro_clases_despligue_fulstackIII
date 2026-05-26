# API Gateway Module

Creates an AWS API Gateway HTTP API that exposes nginx over HTTPS and proxies requests to an HTTP origin.

## Resources
- `aws_apigatewayv2_api`
- `aws_apigatewayv2_integration`
- `aws_apigatewayv2_route` (`ANY /` and `ANY /{proxy+}`)
- `aws_apigatewayv2_stage`

## Inputs
- `name`: API name.
- `nginx_base_url`: HTTP origin URL (must start with `http://`).
- `stage_name`: API stage name (default: `$default`).
- `cors_allowed_origins`: allowed CORS origins.
- `tags`: tags map.

## Outputs
- `api_id`
- `api_endpoint`
- `invoke_url`
- `stage_name`

## Example
```hcl
module "api_gateway" {
  source = "./modules/api_gateway"

  name                 = "colegio-http-api"
  nginx_base_url       = "http://${module.ec2_instances["ec2-api-gw"].public_dns}"
  stage_name           = "$default"
  cors_allowed_origins = ["*"]
  tags = {
    Project = "Colegio Fullstack III"
    Layer   = "Edge"
  }
}
```

## Security note
This first version uses a public HTTP origin and does not use VPC Link.
