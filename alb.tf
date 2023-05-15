provider "aws" {
  region  = "us-east-1"
}
resource "aws_lb" "example" {
  name               = "st2-alb"
  load_balancer_type = "application"
  subnets            = ["subnet-000b0de3b810e035f", "subnet-065181c8ebc43a8bf"]  # Specify the subnets where the ALB should be deployed
  security_groups    = ["sg-021db647ad8c859b9", "sg-00805a4607d286f4d", "sg-0818dfd4afe39f67c"]  # Specify the security group for the ALB

  tags = {
    Name = "st2-alb"
  }
}

# Target groups
resource "aws_lb_target_group" "jenkins" {
  name        = "jenkins-target-group"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    path = "/"
    port = 8080
  }
}

resource "aws_lb_target_group" "app" {
  name        = "app-target-group"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"

  health_check {
    path = "/"
    port = 8080
  }
}

# ALB listeners
resource "aws_lb_listener" "jenkins_listener" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }

  # rules for /jenkins and /jenkins/* paths
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }

  rule {
    priority = 1
    path_pattern = "/jenkins/*"
    action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.jenkins.arn
    }
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  # the rules for /app and /app/* paths
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  rule {
    priority = 1
    path_pattern = "/app/*"
    action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
    }
  }
}






