# build stage
FROM node:18 AS node-builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY tsconfig.json .
COPY src ./src
RUN npx tsc

# runtime stage
FROM heroiclabs/nakama:3.22.0
COPY --from=node-builder /app/build /nakama/data/modules/build
COPY local.yml /nakama/data/local.yml
