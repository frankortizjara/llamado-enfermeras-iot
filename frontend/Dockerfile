# Frontend - Sistema Llamado de Enfermeras
# Stage 1: Build
FROM node:20-alpine AS build

WORKDIR /app

# Copiar package.json
COPY package*.json ./

# Instalar dependencias
RUN npm ci

# Copiar codigo fuente
COPY . .

# Limite de memoria del build de Angular.
# El build es lo mas pesado de toda la stack: en servidores con poca RAM el
# kernel mata el proceso (npm error signal SIGKILL) y la imagen no se genera.
# Ajustable:  docker compose build --build-arg NODE_BUILD_MEMORY=4096 frontend
# Si el servidor tiene <4 GB, mejor construir en otra maquina: 'make release-save'.
ARG NODE_BUILD_MEMORY=1536
ENV NODE_OPTIONS=--max-old-space-size=${NODE_BUILD_MEMORY}

# Construir el proyecto Angular
RUN npm run build

# Stage 2: Serve con Nginx
FROM nginx:alpine

# Copiar configuracion de nginx
COPY ./config/default.conf /etc/nginx/conf.d/default.conf

# Copiar archivos construidos (Angular 17 usa dist/PROJECT_NAME/browser)
COPY --from=build /app/dist/frontend/browser /usr/share/nginx/html

# Exponer puerto
EXPOSE 80

# Ejecutar nginx
CMD ["nginx", "-g", "daemon off;"]
