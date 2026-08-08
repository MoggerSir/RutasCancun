# Rutas Cancún — Web

Frontend web para consultar y planificar viajes en las rutas de transporte
público de Cancún.

## Desarrollo local

```bash
flutter pub get
flutter run -d chrome \
  --dart-define=API_BASE_URL=https://rutascancun.larpmusic.com.mx/api
```

## Publicación

Cada push a `main` ejecuta las pruebas, compila Flutter Web y publica el
resultado en GitHub Pages mediante `.github/workflows/pages.yml`.

El backend, las credenciales, las herramientas administrativas y los datos de
producción no forman parte de este repositorio.
