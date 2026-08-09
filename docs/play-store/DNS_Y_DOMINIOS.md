# DNS y dominios de producción

Dominio definitivo: `rutascancun.com`.

## Registros recomendados en Cloudflare

| Tipo | Nombre | Destino | Proxy |
|---|---|---|---|
| CNAME | `@` | `moggersir.github.io` | DNS only durante validación de GitHub Pages; después puede probarse Proxied |
| CNAME | `www` | `rutascancun.com` | Proxied |
| A | `api` | `66.29.133.32` | Proxied |

El puerto público es HTTPS/443; el puerto SSH 22022 no se publica en DNS.

## URLs finales

- Web: `https://rutascancun.com`
- API: `https://api.rutascancun.com/api`
- Salud: `https://api.rutascancun.com/api/health`
- Privacidad: `https://rutascancun.com/privacy.html`

Mantener temporalmente el host antiguo de la API como alias durante al menos
una versión para que las instalaciones beta anteriores no dejen de funcionar.

## Estado detectado el 8 de agosto de 2026

No retirar el dominio anterior hasta comprobar DNS, certificado TLS, CORS,
`/api/health` y carga real desde Android.
