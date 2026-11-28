output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "public_subnet_ids" {
  value = data.aws_subnets.default.ids
}

output "alb_dns_name" {
  value = aws_lb.preview.dns_name
}

output "alb_listener_arn" {
  value = aws_lb_listener.http.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.preview.name
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.preview.name
}