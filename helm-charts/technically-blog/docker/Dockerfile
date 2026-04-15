# Hugo version matches .github/workflows/hugo.yml (extended build for SCSS, etc.).
FROM hugomods/hugo:0.128.0 AS builder

WORKDIR /src
COPY . .

RUN hugo --minify -D --baseURL "http://blog.int.kakwalab.ovh/"

FROM nginx:1.27-alpine AS runner

COPY --from=builder /src/public /usr/share/nginx/html

EXPOSE 80
