FROM ubuntu:18.04

# Maintainer of this image
LABEL maintainer="dragrom@gmail.com"

RUN apt-get update; apt-get install nginx -y
RUN echo "Hostname: $HOSTNAME" > /var/www/html/index.html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]