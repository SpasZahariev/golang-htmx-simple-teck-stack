variable "ecs_cluster_name" {
  default = "loc-ecs-cluster"
}

#application load balancer
variable "alb_name" {
  default = "loc-alb"
}

variable "execution_role_arn" {
  default = "arn:aws:iam::054037109154:role/ecsTaskExecutionRole"
}
