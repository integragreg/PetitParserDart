// Copyright (c) 2012, Lukas Renggli <renggli@gmail.com>

/** Internal method to convert an element to a character code. */
int _toCharCode(Dynamic element) {
  if (element is int) {
    return element;
  }
  String value = element.toString();
  if (value.length != 1) {
    throw new IllegalArgumentException('$value is not a character');
  }
  return value.charCodeAt(0);
}

/** Internal abstract parser class for character classes. */
abstract class _CharacterParser extends Parser {
  String _message;
  _CharacterParser(this._message);
  Result _parse(Context context) {
    final buffer = context.buffer;
    final position = context.position;
    if (position < buffer.length) {
      if (_match(buffer.charCodeAt(position))) {
        return context.success(buffer[position], position + 1);
      }
    }
    return context.failure(_message);
  }
  abstract bool _match(int value);
  Parser neg([String message]) => new _NegatedCharacterParser(message != null ? message : 'no $_message', this);
}

/** Internal parser class for negated character classes. */
class _NegatedCharacterParser extends _CharacterParser {
  final _CharacterParser _parser;
  _NegatedCharacterParser(String message, this._parser) : super(message);
  bool _match(int value) => !_parser._match(value);
  Parser neg([String message]) => _parser;
}

/** Internal parser class for alternative character classes. */
class _AlternativeCharacterParser extends _CharacterParser {
  final List<_CharacterParser> _parsers;
  _AlternativeCharacterParser(String message, this._parsers) : super(message);
  bool _match(int value) {
    for (final parser in _parsers) {
      if (parser._match(value)) {
        return true;
      }
    }
    return false;
  }
}

/** Returns a parser that accepts a specific character only. */
Parser char(Dynamic element, [String message]) {
  return new _CharParser(message != null ? message : '$element expected', _toCharCode(element));
}

class _CharParser extends _CharacterParser {
  final int _char;
  _CharParser(String message, this._char) : super(message);
  bool _match(int value) => _char === value;
}

/** Returns a parser that accepts any digit character. */
Parser digit([String message]) {
  return new _DigitParser(message != null ? message : 'digit expected');
}

class _DigitParser extends _CharacterParser {
  _DigitParser(String message) : super(message);
  bool _match(int value) => 48 <= value && value <= 57;
}

/** Returns a parser that accepts any letter character. */
Parser letter([String message]) {
  return new _LetterParser(message != null ? message : 'letter expected');
}

class _LetterParser extends _CharacterParser {
  _LetterParser(String message) : super(message);
  bool _match(int value) => (65 <= value && value <= 90) || (97 <= value && value <= 122);
}

/** Returns a parser that accepts any lowercase character. */
Parser lowercase([String message]) {
  return new _LowercaseParser(message != null ? message : 'lowercase letter expected');
}

class _LowercaseParser extends _CharacterParser {
  _LowercaseParser(String message) : super(message);
  bool _match(int value) => 97 <= value && value <= 122;
}

/** Returns a parser that accepts the given character class. */
Parser pattern(String element, [String message]) {
  if (_pattern == null) {
    final single = any().map((each) {
      return char(each);
    });
    final multiple = any().seq(char('-')).seq(any()).map((each) {
      return range(each[0], each[2]);
    });
    final positive = multiple.or(single).plus().map((each) {
      return each.length == 1 ? each[0] : new _AlternativeCharacterParser(null, each);
    });
    _pattern = char('^').optional().seq(positive).map((each) {
      return each[0] == null ? each[1] : each[1].neg();
    });
  }
  _CharacterParser parser = _pattern.parse(element).getResult();
  parser._message = message != null ? message : '[$element] expected';
  return parser;
}

Parser _pattern;

/** Returns a parser that accepts any character in the range between [start] and [stop]. */
Parser range(Dynamic start, Dynamic stop, [String message]) {
  return new _RangeParser( message != null ? message : '$start..$stop expected', _toCharCode(start), _toCharCode(stop));
}

class _RangeParser extends _CharacterParser {
  final int _start;
  final int _stop;
  _RangeParser(String message, this._start, this._stop) : super(message);
  bool _match(int value) => _start <= value && value <= _stop;
}

/** Returns a parser that accepts any uppercase character. */
Parser uppercase([String message]) {
  return new _UppercaseParser(message != null ? message : 'uppercase letter expected');
}

class _UppercaseParser extends _CharacterParser {
  _UppercaseParser(String message) : super(message);
  bool _match(int value) => 65 <= value && value <= 90;
}

/** Returns a parser that accepts any whitespace character. */
Parser whitespace([String message]) {
  return new _WhitespaceParser(message != null ? message : 'whitespace expected');
}

class _WhitespaceParser extends _CharacterParser {
  _WhitespaceParser(String message) : super(message);
  bool _match(int value) => value === 9 || value === 10 || value === 12 || value == 13 || value === 32;
}

/** Returns a parser that accepts any word character. */
Parser word([String message]) {
  return new _WordParser(message != null ? message : 'letter or digit expected');
}

class _WordParser extends _CharacterParser {
  _WordParser(String message) : super(message);
  bool _match(int value) => (65 <= value && value <= 90) || (97 <= value && value <= 122) || (48 <= value && value <= 57);
}