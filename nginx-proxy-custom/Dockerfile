FROM docker.io/library/nginx:latest
COPY nginx-custom.conf /etc/nginx/nginx.conf
COPY headers.js /etc/nginx/headers.js
COPY index.html /usr/share/nginx/html/index.html
RUN mkdir -p /usr/share/nginx/html/upload
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
