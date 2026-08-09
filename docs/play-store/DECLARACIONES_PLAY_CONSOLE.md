# Declaraciones recomendadas en Play Console

Estas respuestas describen la versión beta auditada el 8 de agosto de 2026.
Deben revisarse si se agregan anuncios, analítica, cuentas nominativas,
notificaciones o nuevos SDK.

## Contenido de la app

- Contiene anuncios: **No**.
- Acceso a la app: **Todas las funciones principales son accesibles sin iniciar
  sesión**. La app crea internamente una sesión anónima; el revisor no necesita
  credenciales.
- Público objetivo: **13 años o más**. No seleccionar grupos menores de 13.
- Aplicación de noticias: **No**.
- Aplicación gubernamental: **No**.
- Aplicación de salud: **No**.
- Funciones financieras: **No**.
- Permisos sensibles: ubicación aproximada y precisa únicamente en primer
  plano. No se solicita ubicación en segundo plano.

## Clasificación de contenido (IARC)

Clasificación esperada: **Para todos / PEGI 3**, sujeta al resultado de IARC.

- Violencia: No.
- Contenido sexual o desnudez: No.
- Lenguaje ofensivo: No.
- Drogas, alcohol o tabaco: No.
- Apuestas: No.
- Compras digitales: No.
- Comunicación libre entre usuarios: No.
- Contenido generado por usuarios: sólo reportes estructurados de movilidad,
  sin texto libre, imágenes ni perfiles públicos.
- Comparte ubicación con otros usuarios: No.

## Seguridad de los datos

La app cifra la información en tránsito mediante HTTPS. No vende datos y no los
comparte con fines publicitarios.

Declarar como recopilados:

1. **Identificadores del dispositivo u otros identificadores**
   - Identificador aleatorio de instalación.
   - Obligatorio para funcionamiento y prevención de abuso.
   - Finalidad: funcionalidad de la app, seguridad y prevención de fraude.
   - Vinculado a una sesión anónima.

2. **Ubicación aproximada y ubicación precisa**
   - Opcional; el usuario puede usar la app sin concederla.
   - Finalidad: funcionalidad de la app.
   - Los cálculos de viaje se procesan sin crear un historial personal.
   - Si el usuario envía un reporte, sus coordenadas se conservan junto al
     reporte y al identificador anónimo.

3. **Actividad en la app — historial de búsqueda**
   - Texto escrito para buscar lugares.
   - Finalidad: funcionalidad de la app.
   - La API puede mantener temporalmente una clave hash de caché para mejorar
     resultados y rendimiento.

4. **Otro contenido generado por usuarios**
   - Reportes estructurados de movilidad enviados voluntariamente.
   - Finalidad: funcionalidad de la app y mejora del servicio.

No declarar por ahora:

- Nombre, correo o teléfono del usuario.
- Contactos, fotos, audio, archivos o mensajes.
- Información financiera.
- Datos de salud.
- Identificador de publicidad.
- Ubicación en segundo plano.

## Eliminación de datos

La app no ofrece cuentas registradas visibles para el usuario. Las solicitudes
de eliminación del identificador anónimo y sus reportes se atienden en
`privacidad@rutascancun.com`. Si Google presenta la pregunta sobre eliminación,
indicar que no existen cuentas de usuario tradicionales y proporcionar el canal
de privacidad.

## Notificaciones

No declarar ni solicitar `POST_NOTIFICATIONS` en esta versión. Cuando exista una
función visible de alertas, se añadirá el permiso y se actualizarán la política,
la ficha y Seguridad de los datos antes de publicar esa versión.
