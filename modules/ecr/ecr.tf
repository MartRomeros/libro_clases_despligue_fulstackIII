module "ecr_colegio" {

  source                          = "terraform-aws-modules/ecr/aws"
  version                         = "~> 2.3.0"
  repository_name                 = var.name
  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push   = true
  create_lifecycle_policy         = false

  tags = {
    Name = var.name
  }
}