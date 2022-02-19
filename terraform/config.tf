terraform {
  required_version = "= 1.0.7"
}

provider "aws" {
  region = local.region
  default_tags {
    tags = {
      repository = "strapi-fargate-with-aurora-serverless"
    }
  }
}

provider "http" {
}
