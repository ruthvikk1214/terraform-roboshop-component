resource "aws_instance" "main" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  subnet_id              = local.private_subnet_ids[0]
  vpc_security_group_ids = [local.sg_id]
  tags = merge(
    {
      Name = "${var.project}-${var.environment}-${var.component}"
    },
    local.common_tags
  )
}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id,
  ]

  connection {
    type     = "ssh"
    host     = aws_instance.main.private_ip
    user     = "ec2-user"
    password = "DevOps321"
  }

  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo /tmp/bootstrap.sh main ${var.component} ${var.environment}"
    ]
  }
}

resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on  = [terraform_data.main]
}

resource "aws_ami_from_instance" "main" {
  source_instance_id = aws_instance.main.id
  name               = "${var.project}-${var.environment}-main"
  depends_on         = [aws_ec2_instance_state.main]
  tags = merge(
    {
      Name = "${var.project}-${var.environment}-main"
    },
    local.common_tags
  )
}

resource "aws_lb_target_group" "main" {
  name                 = "${var.project}-${var.environment}-main"
  port                 = local.port_number
  protocol             = "HTTP"
  vpc_id               = local.vpc_id
  deregistration_delay = 30
  health_check {
    path                = local.health_check_path
    port                = local.port_number
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
    matcher             = "200-299"
  }
}

resource "aws_launch_template" "main" {
  name                                 = "${var.project}-${var.environment}-main"
  instance_initiated_shutdown_behavior = "terminate"
  image_id                             = aws_ami_from_instance.main.id
  instance_type                        = "t3.micro"
  vpc_security_group_ids               = [local.sg_id]
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name = "${var.project}-${var.environment}-main"
      },
      local.common_tags
    )
  }
}

resource "aws_autoscaling_group" "main" {
  name                      = "${var.project}-${var.environment}-main"
  vpc_zone_identifier       = local.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.main.arn]
  min_size                  = 1
  max_size                  = 10
  desired_capacity          = 1
  force_delete              = false
  health_check_grace_period = 120
  health_check_type         = "ELB"
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  timeouts {
    delete = "15m"
  }
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-main"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "main_scale_up" {
  name                      = "${var.project}-${var.environment}-main-scale-up"
  autoscaling_group_name    = aws_autoscaling_group.main.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 60
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
resource "aws_alb_listener_rule" "main" {
  listener_arn = local.alb_listener_arn
  priority     = var.rule_priority
  condition {
    host_header {
      values = [local.host_header]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "terraform_data" "main-delete" {
  triggers_replace = [
    aws_instance.main.id,
  ]
  depends_on = [aws_autoscaling_group.main]
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }
}
