FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev

COPY src ./src

# Folder sesi harus bisa ditulis user non-root dan dipasang sebagai volume.
RUN mkdir -p /app/auth_info_baileys && chown -R node:node /app
USER node

VOLUME ["/app/auth_info_baileys"]

CMD ["node", "src/index.js"]
