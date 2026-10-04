FROM node:24-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY src ./src

ENV HOST=0.0.0.0
ENV PORT=4000

EXPOSE 4000

CMD ["node", "src/server.js"]
