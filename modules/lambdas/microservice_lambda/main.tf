data "aws_iam_role" "role" {
  name = "LabRole"
  
}


resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = data.aws_iam_role.role.arn
  package_type  = "Image"
  image_uri     = var.image_uri

  timeout     = 30
  memory_size = 512

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = var.environment_variables
  }
}
