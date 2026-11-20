output "application_url" {
  description = "Local URL of the Flask application."
  value       = "http://127.0.0.1:${var.application_port}"
}

output "network_name" {
  description = "Name of the shared Docker network."
  value       = docker_network.application.name
}

output "redis_volume_name" {
  description = "Name of the persistent Redis data volume."
  value       = docker_volume.redis_data.name
}

output "application_container" {
  description = "Name of the Flask container."
  value       = docker_container.application.name
}

output "redis_container" {
  description = "Name of the Redis container."
  value       = docker_container.redis.name
}
