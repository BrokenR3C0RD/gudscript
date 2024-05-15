import 'package:source_span/source_span.dart';

class SyntaxError extends MultiSourceSpanException {
  final String? help;
  final String? fix;
  SyntaxError(String message, FileSpan span,
      {this.help,
      this.fix,
      String primaryLabel = 'here',
      Map<SourceSpan, String> secondarySpans = const {}})
      : super(message, span, primaryLabel, secondarySpans);

  @override
  String toString({Object? color, String? secondaryColor}) {
    var useColor = false;
    String? primaryColor;
    if (color is String) {
      useColor = true;
      primaryColor = color;
    } else if (color == true) {
      useColor = true;
    }

    final reset = useColor ? '\x1B[0m' : '';
    final red = useColor ? '\x1B[31m' : '';
    final blue = useColor ? '\x1B[34m' : '';
    final cyan = useColor ? '\x1B[36m' : '';

    final helpText = help != null ? '\n${cyan}note$reset: $help' : '';
    final hintText = fix != null ? '\n${cyan}try$reset: $fix' : '';
    if (span == null) {
      return '${red}Syntax Error$reset: $message$helpText$hintText';
    }

    
    final formatted = span!.highlightMultiple(primaryLabel, secondarySpans,
        color: useColor,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor);
    return '${red}Syntax Error$reset: $message$helpText\n  $blue———>$reset ${span!.start.toolString}\n$formatted$hintText';
  }
}
