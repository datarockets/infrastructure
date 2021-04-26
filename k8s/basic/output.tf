locals {
  host_to_ips = transpose({
    for ip, hosts in {
      for name, config in var.ingresses :
        kubernetes_ingress.ingress[name].status[0].load_balancer[0].ingress[0].ip => kubernetes_ingress.ingress[name].spec[*].rule[*].host...
    } : ip => flatten(hosts)
  })
}

output "public_ips" {
  value = {for host, ips in local.host_to_ips : host => ips[0]}
  description = "Returns host to ip map: {hostname1 = ip1, hostname2 = ip2}"
}
