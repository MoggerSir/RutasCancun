/// Una opción de donación mostrada en el diálogo de apoyo.
///
/// [url] apunta siempre a un link de pago de Mercado Pago. El de
/// [DonationOption.custom] no lleva monto fijo (el donante lo decide en
/// Mercado Pago); los demás cobran exactamente lo que indica [amountLabel]
/// — si el link cambia de monto, actualiza [amountLabel] junto con él para
/// no mostrar una cifra distinta a la que de verdad se va a cobrar.
class DonationOption {
  const DonationOption({
    required this.amountLabel,
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.url,
  });

  final String amountLabel;
  final String title;
  final String description;

  /// Ruta a un asset SVG en `assets/icons/` (estilo Iconoir, `currentColor`).
  final String iconAsset;
  final String url;
}

const donationOptions = <DonationOption>[
  DonationOption(
    amountLabel: '\$10 MXN',
    title: 'Un pasaje',
    description: 'Un pasaje más para seguir trazando Cancún.',
    iconAsset: 'assets/icons/bus.svg',
    url: 'https://mpago.la/2Df1C1u',
  ),
  DonationOption(
    amountLabel: '\$30 MXN',
    title: 'Un cafecito',
    description: 'Combustible para el desarrollador.',
    iconAsset: 'assets/icons/coffee-cup.svg',
    url: 'https://mpago.la/2Ksdmbd',
  ),
  DonationOption(
    amountLabel: '\$50 MXN',
    title: 'Cazador de rutas',
    description: 'Ayúdame a salir a buscar y documentar nuevas rutas.',
    iconAsset: 'assets/icons/compass.svg',
    url: 'https://mpago.la/2T92VHw',
  ),
  DonationOption(
    amountLabel: '\$100 MXN',
    title: 'Patrocina una ruta',
    description:
        'A veces conseguir una ruta implica subirme al camión, recorrerla '
        'completa o pedir apoyo directamente a los choferes para poder '
        'trazarla. Tu aporte ayuda a cubrir esos recorridos.',
    iconAsset: 'assets/icons/van.svg',
    url: 'https://mpago.la/1gpATj6',
  ),
  DonationOption(
    amountLabel: 'Libre',
    title: 'Apoyo personalizado',
    description: 'Tú decides cuánto apoyar al proyecto.',
    iconAsset: 'assets/icons/heart.svg',
    url: 'https://link.mercadopago.com.mx/rutascancun',
  ),
];
