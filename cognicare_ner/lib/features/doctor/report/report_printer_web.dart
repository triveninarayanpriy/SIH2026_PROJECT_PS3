import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens the report HTML in a new browser tab; the report's own inline script
/// triggers the print dialog on load.
void openPrintableReport(String reportHtml) {
  final web.Blob blob = web.Blob(
    <JSAny>[reportHtml.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final String url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}
