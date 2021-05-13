output "hosts" {
  value = kubernetes_ingress.ingress.spec[*].rule[*].host
}

output "ip" {
  value = kubernetes_ingress.ingress.status[0].load_balancer[0].ingress[0].ip
}
