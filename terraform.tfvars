cluster_iam_role    = "" #
node_group_iam_role = "" #
name                = "cloudacademy"
environment         = "prod"
vpc_cidr            = "10.0.0.0/16"

k8s = {
  version        = "1.27"
  instance_types = [] # 
  capacity_type  = "ON_DEMAND"
  disk_size      = 10
  min_size       = 2
  max_size       = 2
  desired_size   = 2
}

ebs_optimized       = true
block_device_mappings = {
  xvda = {
    device_name = "/dev/xvda"
    ebs = {
      #
    }
  }
}