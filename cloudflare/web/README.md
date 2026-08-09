# Frontend en Cloudflare

El mismo artefacto Flutter generado para GitHub Pages puede publicarse en la
red de Cloudflare para servir `rutascancun.com` y `www.rutascancun.com`. Las
rutas de Worker interceptan los registros proxificados existentes antes de que
el tráfico alcance el reenvío antiguo del registrador.

```bash
flutter build web --release --base-href / \
  --dart-define=API_BASE_URL=https://api.rutascancun.com/api
cd cloudflare/web
npx wrangler@4.50.0 deploy
```
