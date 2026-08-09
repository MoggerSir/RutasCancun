import 'package:flutter/material.dart';
import 'package:rutas_cancun/core/theme/app_colors.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, this.initialSection = LegalSection.about});

  final LegalSection initialSection;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialSection.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Información de la app'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Sobre nosotros'),
              Tab(text: 'Privacidad'),
              Tab(text: 'Términos'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AboutContent(),
            _PrivacyContent(),
            _TermsContent(),
          ],
        ),
      ),
    );
  }
}

enum LegalSection { about, privacy, terms }

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          22,
          22,
          22,
          40 + MediaQuery.of(context).padding.bottom,
        ),
        children: children,
      ),
    );
  }
}

class _AboutContent extends StatelessWidget {
  const _AboutContent();

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      children: [
        _Hero(
          icon: Icons.directions_bus_rounded,
          title: 'Rutas Cancún',
          subtitle: 'Muévete con más claridad por Cancún.',
        ),
        _Section(
          title: 'Qué hacemos',
          body:
              'Rutas Cancún ayuda a explorar recorridos de transporte público, '
              'comparar alternativas y visualizar cómo llegar de un punto a '
              'otro. La información combina datos recopilados, referencias '
              'públicas y aportes de la comunidad.',
        ),
        _Section(
          title: 'Proyecto independiente',
          body: 'No somos una dependencia gubernamental ni representamos a '
              'concesionarios, sindicatos u operadores de transporte. Los '
              'recorridos, horarios y tiempos son informativos y pueden cambiar '
              'sin aviso. Verifica señalización, indicaciones del operador y '
              'condiciones reales antes de viajar.',
        ),
        _Section(
          title: 'Contacto',
          body: 'Soporte, privacidad y correcciones de rutas:\n'
              'soporte@rutascancun.com\n\n'
              'Sitio web: https://rutascancun.com',
        ),
        _Footnote(text: 'Versión beta · Actualizado el 8 de agosto de 2026'),
      ],
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      children: [
        _Hero(
          icon: Icons.verified_user_outlined,
          title: 'Política de privacidad',
          subtitle: 'Control y transparencia sobre tus datos.',
        ),
        _Section(
          title: 'Resumen',
          body:
              'Puedes consultar rutas sin crear una cuenta con nombre o correo. '
              'La ubicación es opcional y sólo se solicita al activar una '
              'función que la necesita. La app sigue funcionando de forma '
              'limitada si decides no compartirla.',
        ),
        _Section(
          title: 'Datos que tratamos',
          body:
              '• Identificador aleatorio del dispositivo: se genera en la app '
              'para iniciar una sesión anónima, prevenir abuso y asociar '
              'reportes comunitarios.\n'
              '• Ubicación aproximada o precisa: si das permiso, se usa para '
              'centrar el mapa, buscar rutas cercanas y calcular recorridos.\n'
              '• Puntos elegidos en el mapa: origen y destino se envían por '
              'HTTPS a nuestra API para calcular alternativas.\n'
              '• Reportes voluntarios: tipo de reporte, ruta, coordenadas, fecha '
              'y usuario anónimo.\n'
              '• Datos técnicos básicos: dirección IP, agente de usuario y '
              'registros de seguridad que el servidor pueda procesar.',
        ),
        _Section(
          title: 'Cómo usamos los datos',
          body:
              'Los usamos únicamente para entregar las funciones solicitadas, '
              'mejorar la precisión de rutas, mantener sesiones anónimas, '
              'proteger el servicio y atender errores. No vendemos datos '
              'personales ni usamos la ubicación para publicidad.',
        ),
        _Section(
          title: 'Servicios necesarios',
          body:
              'El mapa utiliza CARTO y datos de OpenStreetMap. El buscador de '
              'lugares usa Photon; el texto de búsqueda se procesa para devolver '
              'sugerencias. Nuestra infraestructura y protección web pueden '
              'operar mediante Cloudflare. Estos proveedores pueden recibir '
              'datos técnicos como la dirección IP conforme a sus propias '
              'políticas.',
        ),
        _Section(
          title: 'Conservación y seguridad',
          body: 'Las comunicaciones con nuestra API usan HTTPS. Conservamos '
              'identificadores anónimos y reportes mientras sean necesarios para '
              'operar, proteger y mejorar el servicio, o hasta que proceda una '
              'solicitud válida de eliminación. Los puntos usados únicamente '
              'para calcular un viaje no se incorporan como historial personal '
              'de viajes.',
        ),
        _Section(
          title: 'Tus decisiones y derechos',
          body: 'Puedes negar o revocar la ubicación desde Ajustes de Android. '
              'También puedes solicitar acceso, corrección o eliminación de '
              'datos asociados a tu instalación escribiendo a '
              'privacidad@rutascancun.com. Podremos pedir información técnica '
              'mínima para localizar el identificador correcto.',
        ),
        _Section(
          title: 'Menores y cambios',
          body: 'La app está dirigida a personas de 13 años o más y no está '
              'diseñada específicamente para menores de 13 años. Publicaremos '
              'cambios materiales en esta sección y en rutascancun.com.',
        ),
        _Footnote(
          text:
              'Vigente desde el 8 de agosto de 2026 · privacidad@rutascancun.com',
        ),
      ],
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return const _LegalPage(
      children: [
        _Hero(
          icon: Icons.description_outlined,
          title: 'Términos de uso',
          subtitle: 'Información útil, decisiones responsables.',
        ),
        _Section(
          title: 'Servicio informativo',
          body:
              'Rutas Cancún ofrece referencias de movilidad. No garantiza que '
              'una unidad pase, que un recorrido permanezca sin cambios, que '
              'exista disponibilidad ni que una estimación coincida con el '
              'tráfico real.',
        ),
        _Section(
          title: 'Uso seguro',
          body:
              'No manipules la app mientras conduces. Mantente atento al entorno, '
              'cruza por lugares seguros y sigue las instrucciones de autoridades '
              'y operadores. Ante una emergencia utiliza los canales oficiales.',
        ),
        _Section(
          title: 'Aportes comunitarios',
          body:
              'Envía únicamente información de buena fe. No se permite contenido '
              'falso, ilegal, ofensivo, automatizado o destinado a perjudicar el '
              'servicio. Podemos retirar reportes y limitar instalaciones ante '
              'abuso.',
        ),
        _Section(
          title: 'Disponibilidad',
          body:
              'Podemos modificar, suspender o actualizar funciones para corregir '
              'errores, proteger el sistema o mejorar la experiencia. El servicio '
              'se proporciona en su estado disponible.',
        ),
        _Section(
          title: 'Mapas y fuentes',
          body:
              'Las teselas cartográficas se muestran con tecnología CARTO y datos '
              'de OpenStreetMap. Las marcas y nombres de terceros pertenecen a '
              'sus respectivos titulares.',
        ),
        _Section(
          title: 'Contacto',
          body: 'Preguntas, avisos o reclamaciones: legal@rutascancun.com',
        ),
        _Footnote(text: 'Vigente desde el 8 de agosto de 2026'),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 34),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 7),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
