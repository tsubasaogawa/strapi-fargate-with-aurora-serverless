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
  for_each          = local.vpc.subnets.private
  vpc_id            = aws_vpc.this.id
  cidr_block        = lookup(each.value, "cidr_block")
  availability_zone = lookup(each.value, "az")

  tags = {
    Name = "${local.name}-private-${each.key}"
  }
}

resource "aws_subnet" "public" {
  for_each          = local.vpc.subnets.public
  vpc_id            = aws_vpc.this.id
  cidr_block        = lookup(each.value, "cidr_block")
  availability_zone = lookup(each.value, "az")

  tags = {
    Name = "${local.name}-public-${each.key}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name}-route-table-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}-route-table-private"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = lookup(each.value, "id")
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = lookup(each.value, "id")
  route_table_id = aws_route_table.private.id
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

  tags = {
    Name = "${local.name}-rds-security-group"
  }
}

resource "aws_security_group" "task" {
  vpc_id = aws_vpc.this.id
  name   = "${local.name}-task-security-group"

  ingress {
    protocol  = "tcp"
    from_port = 1337
    to_port   = 1337
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

  tags = {
    Name = "${local.name}-task-security-group"
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-rds-subnet-group"
  subnet_ids = values(aws_subnet.private)[*].id
}

resource "aws_rds_cluster" "this" {
  cluster_identifier     = "cluster-${local.name}"
  engine_mode            = "serverless"
  engine                 = "aurora-mysql"
  engine_version         = "5.7"
  database_name          = "strapi"
  master_username        = "strapi"
  master_password        = var.master_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.rds.id]

  scaling_configuration {
    auto_pause               = true
    seconds_until_auto_pause = 300
    max_capacity             = 1
    min_capacity             = 1
    timeout_action           = "ForceApplyCapacityChange"
  }

  lifecycle {
    ignore_changes = [
      master_password,
    ]
  }
}

resource "aws_ecs_cluster" "this" {
  name               = "${local.name}-cluster"
  capacity_providers = ["FARGATE_SPOT"]

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  execution_role_arn       = aws_iam_role.task_execution.arn
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = jsonencode([
    {
      name  = local.name
      image = aws_ecr_repository.this.repository_url
      environment = [
        {
          name  = "DATABASE_CLIENT"
          value = "mysql"
        },
        {
          name  = "DATABASE_HOST"
          value = "mysql"
        },
        {
          name  = "DATABASE_PORT"
          value = "3306"
        },
        {
          name  = "DATABASE_NAME"
          value = "strapi"
        },
        {
          name  = "DATABASE_USERNAME"
          value = "strapi"
        },
        {
          name  = "DATABASE_PASSWORD"
          value = var.master_password
        },
        {
          name  = "DATABASE_SSL"
          value = "false"
        }
      ]
      essential = true
      portMappings = [
        {
          containerPort = 1337
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.logs.name
          awslogs-region        = local.region
          awslogs-stream-prefix = local.name
        }
      }
    }
  ])
  lifecycle {
    ignore_changes = [
      container_definitions["environment"],
    ]
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.logs.name
  retention_in_days = 30
}

data "aws_iam_policy_document" "task_execution" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}
resource "aws_iam_role" "task_execution" {
  name = "${local.name}-task-execution-role"
  # tags               = var.tags
  description        = "Execution role of ${local.name}'s task"
  assume_role_policy = data.aws_iam_policy_document.task_execution.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
