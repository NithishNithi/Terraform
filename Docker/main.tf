terraform {
    required_providers {
        docker = {
            source  = "kreuzwerker/docker"
            version = "3.0.2"
        }
    }
}

provider "docker" {}

resource "docker_image" "nginx" {
    name = "nginx:latest"
    keep_locally = false
}

resource "docker_network" "qa_network" {
  name = "qa_network"
  driver = "bridge"
}

resource "docker_container" "nginx" {
    name = "nginx_1"
    image = docker_image.nginx.image_id

    networks_advanced {
      name = docker_network.qa_network.name
    }

    ports  {
        internal = 80
        external = 8888
    }

}