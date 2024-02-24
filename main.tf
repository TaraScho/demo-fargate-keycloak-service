provider "aws" {
  region     = "${var.region}"
  access_key = "${var.frontend_aws_access_key_id}"
  secret_key = "${var.frontend_aws_secret_access_key}"

  default_tags {
    tags = var.aws_tags
  }
}

resource "aws_vpc" "fargate-vpc" {
  cidr_block = var.cidr
}
 
resource "aws_internet_gateway" "fargate-igw" {
  vpc_id = aws_vpc.fargate-vpc.id
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.fargate-vpc.id
  cidr_block        = element(var.private_subnets, count.index)
  availability_zone = element(var.availability_zones, count.index)
  count             = length(var.private_subnets)
}
 
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.fargate-vpc.id
  cidr_block              = element(var.public_subnets, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  count                   = length(var.public_subnets)
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.fargate-vpc.id
}
 
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.fargate-igw.id
}
 
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_nat_gateway" "main" {
  count         = length(var.private_subnets)
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  depends_on    = [aws_internet_gateway.fargate-igw]
}
 
resource "aws_eip" "nat" {
  count = length(var.private_subnets)
}

resource "aws_security_group" "alb" {
  name   = "${var.name}-sg-alb"
  vpc_id = aws_vpc.fargate-vpc.id
 
  ingress {
   protocol         = "tcp"
   from_port        = 80
   to_port          = 80
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }
 
  ingress {
   protocol         = "tcp"
   from_port        = 443
   to_port          = 443
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }
 
  egress {
   protocol         = "-1"
   from_port        = 0
   to_port          = 0
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name   = "${var.name}-sg-task"
  vpc_id = aws_vpc.fargate-vpc.id
 
  ingress {
   protocol         = "tcp"
   from_port        = var.container_port
   to_port          = var.container_port
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }
 
  egress {
   protocol         = "-1"
   from_port        = 0
   to_port          = 0
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster"
}

resource "aws_ecs_task_definition" "main" {
  network_mode             = "awsvpc"
  family                   = "cool-courses-services"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
   name        = "${var.name}-container"
   image       = "${var.container_image}"
   essential   = true
   portMappings = [{
     containerPort = var.container_port
     hostPort      = var.container_port
     protocol      = "tcp"
   }]
   environment  = [
        {
          name  = "KEYCLOAK_ADMIN"
          value = var.keycloak_admin
        },
        {
          name  = "KEYCLOAK_ADMIN_PASSWORD"
          value = var.keycloak_admin_password
        },
        {
          name = "KC_HEALTH_ENABLED"
          value = "true"
        },

   ]
   command = ["start-dev"]
   logConfiguration = {
     logDriver = "awslogs"
     options = {
       "awslogs-group"         = "${var.name}-log-group"
       "awslogs-region"        = "${var.region}"
       "awslogs-stream-prefix" = "${var.name}"
     }
   } 
}])
}

resource aws_cloudwatch_log_group "ecs_log_group" {
  name = "${var.name}-log-group"
}

resource "aws_lb" "main" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets =     aws_subnet.public[*].id

  enable_deletion_protection = false
}

resource "aws_alb_target_group" "main" {
  name        = "${var.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.fargate-vpc.id
  target_type = "ip"

  health_check {
   healthy_threshold   = "3"
   interval            = "30"
   protocol            = "HTTP"
   matcher             = "200"
   timeout             = "3"
   path                = var.health_check_path
   unhealthy_threshold = "2"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"
 
  default_action {
   type = "forward"
   target_group_arn = aws_alb_target_group.main.arn
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name}-ecsTaskRole"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name}-ecsTaskExecutionRole"
 
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "my_service" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public.*.id
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.main.arn
    container_name   = "${var.name}-container"
    container_port   = var.container_port
  }

  depends_on = [
    aws_alb_listener.http,
  ]
}
