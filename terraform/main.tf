provider "aws" {
  region = "eu-north-1"
}

resource "aws_ecs_cluster" "loc_cluster" {
  name = var.ecs_cluster_name

}
# Setup public subnet that has a route to an internet gateway
# resource "aws_vpc" "loc_vpc" {
#   cidr_block = "10.0.0.0/16"
# }

# resource "aws_internet_gateway" "igw" {
#   # vpc_id = aws_vpc.loc_vpc.id
#   vpc_id = var.og_vpc_id
# }

resource "aws_subnet" "public_subnet_1" {
  # vpc_id                  = aws_vpc.loc_vpc.id
  vpc_id = var.og_vpc_id
  # cidr_block              = "10.0.2.0/24" # Different CIDR block
  cidr_block              = "172.31.48.0/20" # Different CIDR block
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1a" # Specify the availability zone
}

resource "aws_subnet" "public_subnet_2" {
  # vpc_id                  = aws_vpc.loc_vpc.id
  vpc_id = var.og_vpc_id
  # cidr_block              = "10.0.3.0/24" # Different CIDR block
  cidr_block              = "172.31.64.0/20" # Different CIDR block
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1b" # Different availability zone
}

resource "aws_route_table" "public_rt" {
  # vpc_id = aws_vpc.loc_vpc.id
  vpc_id = var.og_vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    # gateway_id = aws_internet_gateway.igw.id
    gateway_id = var.igw_id
  }
}

resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# security group setup
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = var.og_vpc_id
  # vpc_id = aws_vpc.loc_vpc.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow traffic from ALB"
  vpc_id      = var.og_vpc_id
  # vpc_id = aws_vpc.loc_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# task definition setup
resource "aws_ecs_task_definition" "loc_task" {
  family = "loc-task-family"
  container_definitions = jsonencode([
    {
      name      = "loc-container"
      image     = "054037109154.dkr.ecr.eu-north-1.amazonaws.com/first-namespace/first-repo:latest"
      essential = true
      portMappings = [
        {
          name          = "loc-container-8080-tcp"
          containerPort = 8080
          hostPort      = 8080
          appProtocol   = "http"
        },
        {
          name          = "loc-container-80-tcp"
          containerPort = 80
          hostPort      = 80
          appProtocol   = "http"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/loc-task"
          awslogs-region        = "eu-north-1"
          awslogs-create-group  = "true"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.execution_role_arn
  # task_role_arn            = var.task_role_arn
  network_mode = "awsvpc"
  cpu          = 256
  memory       = 512

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_lb" "loc_alb" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  # security_groups = ["sg-04d502a839c7338ec"]
  # subnets         = ["subnet-0eb6b3d96b986165e", "subnet-0e77ab66e0751c549"]
}

resource "aws_lb_target_group" "loc_target_group" {
  name     = "loc-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.og_vpc_id
  # vpc_id      = aws_vpc.loc_vpc.id
  target_type = "ip"
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "loc_listener" {
  load_balancer_arn = aws_lb.loc_alb.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.loc_target_group.arn
  }
}

# ecs service setup
resource "aws_ecs_service" "loc_service" {
  name            = "loc-ecs-service"
  cluster         = aws_ecs_cluster.loc_cluster.id
  task_definition = aws_ecs_task_definition.loc_task.arn
  # launch_type     = "FARGATE"
  # platform_version = "1.3.0" # Specify the desired platform version


  desired_count = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    # subnets = ["subnet-0eb6b3d96b986165e", "subnet-0e77ab66e0751c549"]
    subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    # security_groups = [aws_security_group.ecs_sg.id]
    security_groups  = ["sg-04d502a839c7338ec"]
    assign_public_ip = true # Enable public IP assignment
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.loc_target_group.arn
    container_name   = "loc-container"
    container_port   = 8080
  }
}

