locals {
  name = "strapi"
  resource_ids = {

  }
  ecr = {
    repository_name = local.name
  }

  vpc = {
    cidr_block = "10.1.0.0/16"
    subnets = {
      private = {
        "1a" = {
          cidr_block = "10.1.0.0/24"
          az         = "ap-northeast-1a"
        }
        "1c" = {
          cidr_block = "10.1.1.0/24"
          az         = "ap-northeast-1c"
        }
      }
      public = {
        "1a" = {
          cidr_block = "10.1.2.0/24"
          az         = "ap-northeast-1a"
        }
        "1c" = {
          cidr_block = "10.1.3.0/24"
          az         = "ap-northeast-1c"
        }
      }
    }
  }
}
