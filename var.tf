variable "project_name" {
    type = string
    description = "only for project name"
    default = "developer-111120"
}
variable "nodes_disk_size" {
    
    description = "Allocating disk space to  k8s-nodes in GB"
    default = 20
}
variable "machine_type_k8s_nodes" {
    type = string
    description = "(optional) describe your variable"
    default = "e2-micro"
}