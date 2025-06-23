FROM node:lts AS build
WORKDIR /build

COPY package.json package-lock.json .
RUN npm ci

COPY . .

RUN npm run build

FROM caddy:2
WORKDIR /run

COPY --from=build /build/dist/ .

EXPOSE 80/tcp
ENTRYPOINT [ "caddy", "file-server", "--root=/run" ]