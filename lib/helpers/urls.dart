String getSubdomain() {
  final uri = Uri.base;
  final host = uri.host; // ex: loja1.zapdelivery.com

  if (host.contains('.zapdelivery.com')) {
    return host.split('.zapdelivery.com')[0]; // "loja1"
  }
  return '';
}
