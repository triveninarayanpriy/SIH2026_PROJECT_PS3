// Opens a printable HTML report. Web opens a new tab and triggers the print
// dialog; other platforms are a no-op (the doctor tier runs on web).
export 'report_printer_io.dart'
    if (dart.library.html) 'report_printer_web.dart';
