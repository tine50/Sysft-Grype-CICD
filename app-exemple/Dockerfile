# Image de base Node.js (Alpine = plus légère, plus de paquets à inventorier)
FROM node:20-alpine

WORKDIR /app

# Copie des fichiers du projet
COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY index.js .

EXPOSE 3000
CMD ["node", "index.js"]
