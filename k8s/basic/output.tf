locals {
  host_to_ips = transpose({
    for ip, hosts in {
      for name, config in var.ingresses :
        module.ingress[name].ip => module.ingress[name].hosts...
    } : ip => flatten(hosts)
  })
}

output "public_ips" {
  value = {for host, ips in local.host_to_ips : host => ips[0]}
  description = "Returns host to ip map: {hostname1 = ip1, hostname2 = ip2}"
}

output "ingress_load_balancers" {
  value = {for name, ingress in var.ingresses : name => {
    ip = module.ingress[name].ip
    hostname = module.ingress[name].hostname
  }}
}
