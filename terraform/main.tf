resource "docker_network" "application" {
  name   = "cis4930-assignment5-net"
  driver = "bridge"
}

resource "docker_volume" "redis_data" {
  name = "cis4930-assignment5-redis-data"
}

resource "docker_image" "redis" {
  name         = "redis:7.4-alpine"
  keep_locally = true
}

resource "docker_image" "application" {
  name         = "cis4930-assignment5-app:1.2"
  keep_locally = true

  build {
    context = abspath("${path.module}/../app")
  }

  triggers = {
    application  = filesha256("${path.module}/../app/app.py")
    dockerfile   = filesha256("${path.module}/../app/Dockerfile")
    requirements = filesha256("${path.module}/../app/requirements.txt")
    dockerignore = filesha256("${path.module}/../app/.dockerignore")
  }
}

resource "docker_container" "redis" {
  name    = "redis"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  command = [
    "redis-server",
    "--appendonly", "yes",
    "--appendfsync", "always"
  ]

  network_mode = docker_network.application.name

  networks_advanced {
    name = docker_network.application.name
  }

  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }

  labels {
    label = "com.cis4930.project"
    value = "assignment5"
  }
}

resource "docker_container" "application" {
  name    = "assignment5-app"
  image   = docker_image.application.image_id
  restart = "unless-stopped"

  env = [
    "REDIS_HOST=redis",
    "REDIS_PORT=6379"
  ]

  network_mode = docker_network.application.name

  networks_advanced {
    name = docker_network.application.name
  }

  ports {
    internal = 5000
    external = var.application_port
    ip       = "127.0.0.1"
  }

  labels {
    label = "com.cis4930.project"
    value = "assignment5"
  }

  depends_on = [
    docker_container.redis
  ]
}
