# Backend - Sistema Llamado de Enfermeras
FROM node:20-alpine

# Crear directorio de trabajo
WORKDIR /app

# Copiar package.json y package-lock.json
COPY package*.json ./

# Instalar dependencias de produccion
#RUN npm ci --only=production
RUN npm install --omit=dev

# Copiar codigo fuente
COPY src/ ./src/

# Crear directorio para firmwares y uploads de audio
RUN mkdir -p /app/firmwares /app/uploads/audio

# Exponer puerto
EXPOSE 4000

# Variables de entorno por defecto
ENV NODE_ENV=production
ENV PORT=4000

# Comando de inicio
CMD ["node", "src/index.js"]
