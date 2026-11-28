output "preview_url" {
  value = "http://${data.terraform_remote_state.base.outputs.alb_dns_name}${local.route_prefix}/"
}

output "healthcheck_url" {
  value = "http://${data.terraform_remote_state.base.outputs.alb_dns_name}${local.route_prefix}/healthz"
}

output "ecs_service_name" {
  value = aws_ecs_service.preview.name
}