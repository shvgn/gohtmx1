FROM oven/bun:alpine as bun-builder
ADD . /app
WORKDIR /app
RUN mkdir -p ./static
RUN bun x tailwindcss -o ./static/index.css --minify
RUN bun build --minify ./index.ts --outfile=./static/index.js

FROM golang:1.21-alpine as go-builder
RUN apk --no-cache add make curl bash build-base git ca-certificates
ADD . /app
WORKDIR /app
COPY --from=bun-builder /app/static /app/static
# RUN go install github.com/a-h/templ/cmd/templ@latest
RUN go install github.com/a-h/templ/cmd/templ@v0.2.408
RUN /go/bin/templ generate
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o app .

FROM alpine:3
RUN mkdir /app
COPY --from=go-builder /app/app /app/app
