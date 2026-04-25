# Obtener el rol LabRole preexistente de AWS Academy
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Creación del repositorio ECR para el microservicio
resource "aws_ecr_repository" "repo" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  # Habilitar escaneo de seguridad al subir imágenes
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = var.repository_name
    Environment = var.environment
  }
}

# Política de repositorio para otorgar permisos a Lambda y AWS Academy
resource "aws_ecr_repository_policy" "repo_policy" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAndLabRolePull"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
          AWS     = data.aws_iam_role.lab_role.arn
        }
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
