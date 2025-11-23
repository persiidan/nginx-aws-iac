#!/bin/bash
dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker

docker pull idanpersi/nginx-port:latest
docker run -d -p 80:80 --name nginx idanpersi/nginx-port:latest