// Copyright (c) 2013, Lukas Renggli <renggli@gmail.com>

part of petitparser;

/**
 * A parser that delegates to another one. Normally users do not need to
 * directly use a delegate parser.
 */
class _DelegateParser extends Parser {

  Parser _delegate;

  _DelegateParser(this._delegate);

  Result _parse(Context context) {
    return _delegate._parse(context);
  }

  List<Parser> get children => [_delegate];

  void replace(Parser source, Parser target) {
    super.replace(source, target);
    if (_delegate == source) {
      _delegate = target;
    }
  }

  Parser copy() => new _DelegateParser(_delegate);

}

/**
 * A parser that succeeds only at the end of the input.
 */
class _EndOfInputParser extends _DelegateParser {

  final String _message;

  _EndOfInputParser(parser, this._message) : super(parser);

  Result _parse(Context context) {
    var result = _delegate._parse(context);
    if (result.isFailure || result.position == result.buffer.length) {
      return result;
    }
    return result.failure(_message, result.position);
  }

  Parser copy() => new _EndOfInputParser(_delegate, _message);

  bool match(dynamic other, [Set<Parser> seen]) {
    return super.match(other, seen) && _message == other._message;
  }

}

/**
 * The and-predicate, a parser that succeeds whenever its delegate does, but
 * does not consume the input stream [Parr 1994, 1995].
 */
class _AndParser extends _DelegateParser {

  _AndParser(parser) : super(parser);

  Result _parse(Context context) {
    var result = _delegate._parse(context);
    if (result.isSuccess) {
      return context.success(result.value);
    } else {
      return result;
    }
  }

  Parser copy() => new _AndParser(_delegate);

}

/**
 * The not-predicate, a parser that succeeds whenever its delegate does not,
 * but consumes no input [Parr 1994, 1995].
 */
class _NotParser extends _DelegateParser {

  final String _message;

  _NotParser(parser, this._message) : super(parser);

  Result _parse(Context context) {
    var result = _delegate._parse(context);
    if (result.isFailure) {
      return context.success(null);
    } else {
      return context.failure(_message);
    }
  }

  Parser copy() => new _NotParser(_delegate, _message);

  bool match(dynamic other, [Set<Parser> seen]) {
    return super.match(other, seen) && _message == other._message;
  }

}

/**
 * A parser that optionally parsers its delegate, or answers nil.
 */
class _OptionalParser extends _DelegateParser {

  final dynamic _otherwise;

  _OptionalParser(parser, this._otherwise) : super(parser);

  Result _parse(Context context) {
    var result = _delegate._parse(context);
    if (result.isSuccess) {
      return result;
    } else {
      return context.success(_otherwise);
    }
  }

  Parser copy() => new _OptionalParser(_delegate, _otherwise);

  bool match(dynamic other, [Set<Parser> seen]) {
    return super.match(other, seen) && _otherwise == other._otherwise;
  }

}

/**
 * A parser that repeatedly parses a sequence of parsers.
 */
class _RepeatingParser extends _DelegateParser {

  final int _min;
  final int _max;

  _RepeatingParser(parser, this._min, this._max) : super(parser);

  Result _parse(Context context) {
    var current = context;
    var elements = new List();
    while (elements.length < _min) {
      var result = _delegate._parse(current);
      if (result.isFailure) {
        return result;
      }
      elements.add(result.value);
      current = result;
    }
    while (elements.length < _max) {
      var result = _delegate._parse(current);
      if (result.isFailure) {
        return current.success(elements);
      }
      elements.add(result.value);
      current = result;
    }
    return current.success(elements);
  }

  Parser copy() => new _RepeatingParser(_delegate, _min, _max);

  bool match(dynamic other, [Set<Parser> seen]) {
    return super.match(other, seen)
        && _min == other._min
        && _max == other._max;
  }

}

/**
 * Abstract parser that parses a list of things in some way.
 */
abstract class _ListParser extends Parser {

  final List<Parser> _parsers;

  _ListParser(this._parsers);

  List<Parser> get children => _parsers;

  void replace(Parser source, Parser target) {
    super.replace(source, target);
    for (var i = 0; i < _parsers.length; i++) {
      if (_parsers[i] == source) {
        _parsers[i] = target;
      }
    }
  }

}

/**
 * A parser that uses the first parser that succeeds.
 */
class _ChoiceParser extends _ListParser {

  _ChoiceParser(parsers) : super(parsers);

  Result _parse(Context context) {
    var result;
    for (var parser in _parsers) {
      result = parser._parse(context);
      if (result.isSuccess) {
        return result;
      }
    }
    return result;
  }

  Parser or(Parser other) {
    var parsers = new List.from(_parsers);
    parsers.add(other);
    return new _ChoiceParser(parsers);
  }

  Parser copy() => new _ChoiceParser(new List.from(_parsers));

}

/**
 * A parser that parses a sequence of parsers.
 */
class _SequenceParser extends _ListParser {

  _SequenceParser(parsers) : super(parsers);

  Result _parse(Context context) {
    var current = context;
    var elements = new List(_parsers.length);
    for (var i = 0; i < _parsers.length; i++) {
      var result = _parsers[i]._parse(current);
      if (result.isFailure) {
        return result;
      }
      elements[i] = result.value;
      current = result;
    }
    return current.success(elements);
  }

  Parser seq(Parser other) {
    var parsers = new List.from(_parsers);
    parsers.add(other);
    return new _SequenceParser(parsers);
  }

  Parser copy() => new _SequenceParser(new List.from(_parsers));

}
