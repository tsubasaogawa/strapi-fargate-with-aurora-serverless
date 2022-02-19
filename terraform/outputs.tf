output "database_host" {
  value = aws_rds_cluster.this.endpoint
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_ids" {
  value = {
    private = values(aws_subnet.private)[*].id
    public  = values(aws_subnet.public)[*].id
  }
}

output "security_group_ids" {
  value = {
    rds  = aws_security_group.rds.id
    task = aws_security_group.task.id
  }
}

output "ecs_cluster_name" {
    value = aws_ecs_cluster.this.name
}

output "task_definition_family" {
    value = aws_ecs_task_definition.this.family
}

output "region" {
  value = local.region
}
