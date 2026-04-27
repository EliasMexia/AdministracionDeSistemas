FROM nginx:alpine

# Ocultar la version del servidor (server tokens)
RUN sed -i 's/http {/http {\n    server_tokens off;/g' /etc/nginx/nginx.conf

# Cambiar el puerto al 8080 para poder ejecutarlo sin ser root
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf

# Crear grupo y usuario no administrativo, y darle permisos sobre las carpetas de nginx
RUN addgroup -g 1000 webgroup && \
    adduser -u 1000 -D -S -G webgroup webuser && \
    chown -R webuser:webgroup /var/cache/nginx /var/run /var/log/nginx /usr/share/nginx/html /etc/nginx/conf.d

# Cambiar al usuario webuser
USER webuser

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
