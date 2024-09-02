output "cloudsql_db_private_ip" {
  value = google_sql_database_instance.mydbinstance.private_ip_address
}

output "mydb_schema" {
  value = google_sql_database.mydbschema.name
}

output "mydb_user" {
  value = google_sql_user.users.name
}

output "mydb_password" {
  value = google_sql_user.users.password
  sensitive = true
}