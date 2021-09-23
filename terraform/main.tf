resource "aws_ecr_repository" "this" {
  name                 = local.ecr.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_vpc" "this" {
  cidr_block       = local.vpc.cidr_block
  instance_tenancy = "default"

  tags = {
    Name = local.name
  }
}

resource "aws_subnet" "private" {
  for_each = local.vpc.subnets.private
  vpc_id     = aws_vpc.this.id
  cidr_block = lookup(each.value, "cidr_block")
  availability_zone = lookup(each.value, "az")

  tags = {
    Name = "${local.name}-private-${each.key}"
  }
}

resource "aws_subnet" "public" {
  for_each = local.vpc.subnets.public
  vpc_id     = aws_vpc.this.id
  cidr_block = lookup(each.value, "cidr_block")
  availability_zone = lookup(each.value, "az")

  tags = {
    Name = "${local.name}-public-${each.key}"
  }
}

resource "aws_security_group" "rds" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-rds-security-group"

  ingress {
    protocol  = "tcp"
    from_port = 3306
    to_port   = 3306
    cidr_blocks = [
      local.vpc.cidr_block
    ]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "this" {
  name = "${local.name}-rds-subnet-group"
  subnet_ids = values(aws_subnet.private)[*].id
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "cluster-${local.name}"
  engine_mode        = "serverless"
  engine               = "aurora-mysql"
  engine_version       = "5.7"
  database_name        = "strapi"
  master_username      = "strapi"
  master_password      = var.master_password
  db_subnet_group_name = aws_db_subnet_group.this.name
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]

  scaling_configuration {
    auto_pause = true
    seconds_until_auto_pause = 300
    max_capacity = 1
    min_capacity = 1
    timeout_action = "ForceApplyCapacityChange"
  }

  lifecycle {
    ignore_changes = [
      master_password,
    ]
  }
}
