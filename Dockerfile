FROM nginx:alpine
EXPOSE 80
RUN echo '<h1>🚀 Yo, this is NGINX!</h1><p>Deployed with Docker + Terraform on AWS</p>' > /usr/share/nginx/html/index.html
