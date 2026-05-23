locals {
  ami_id                    = data.aws_ami.joindevops.id
  vpc_id                    = data.aws_ssm_parameter.vpc_id.value
  backend_alb_listener_arn  = data.aws_ssm_parameter.backend_alb_listener_arn.value
  frontend_alb_listener_arn = data.aws_ssm_parameter.frontend_alb_listener_arn.value
  sg_id                     = data.aws_ssm_parameter.sg_id.value
  alb_listener_arn          = var.component == "frontend" ? data.aws_ssm_parameter.frontend_alb_listener_arn.value : data.aws_ssm_parameter.backend_alb_listener_arn.value
  port_number               = var.component == "frontend" ? "80" : "8080"
  host_header               = var.component == "frontend" ? "${var.component}-${var.environment}.${var.domain_name}" : "${var.component}.backend-alb-${var.environment}.${var.domain_name}"
  health_check_path         = var.component == "frontend" ? "/" : "/health"
  private_subnet_ids        = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
  common_tags = {
    project     = var.project
    environment = var.environment
    terraform   = true
  }
}
