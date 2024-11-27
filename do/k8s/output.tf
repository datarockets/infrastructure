output "k8s_host" {
  value       = digitalocean_kubernetes_cluster.k8s_cluster.endpoint
  description = "Kubernetes management API host"
}

output "k8s_token" {
  value     = digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].token
  sensitive = true
}

output "k8s_ca_certificate" {
  value = base64decode(
    digitalocean_kubernetes_cluster.k8s_cluster.kube_config[0].cluster_ca_certificate
  )
  sensitive = true
}

output "dcr_url" {
  value = digitalocean_container_registry.container_registry.server_url
}

output "dcr_endpoint" {
  value = digitalocean_container_registry.container_registry.endpoint
}

output "dcr_credentials_k8s" {
  value     = digitalocean_container_registry_docker_credentials.dcr_credentials_k8s.docker_credentials
  sensitive = true
}

output "dcr_credentials_cicd" {
  value     = digitalocean_container_registry_docker_credentials.dcr_credentials_cicd.docker_credentials
  sensitive = true
}
