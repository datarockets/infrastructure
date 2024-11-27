output "db_host" {
  value = digitalocean_database_cluster.main.private_host
}

output "db_port" {
  value = digitalocean_database_cluster.main.port
}

output "db_user" {
  value = digitalocean_database_user.db_user.name
}

output "db_password" {
  value     = digitalocean_database_user.db_user.password
  sensitive = true
}

output "db_database" {
  value = digitalocean_database_db.database.name
}
