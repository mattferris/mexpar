mexpar
======

mexpar is a general purpose parsing library written in Perl. It features a
lexical analyzer and token parser with support for entirely custom grammars.
Written as a fun learning project and as the parsing engine for [aims 2.0][aims],
it now lives as it's own project in order to decouple it's development from
[aims][aims].

[aims]: https://bueller.ca/software/aims

mexpar roughly stands for Matt's lEXical analyser and PARser.

Quickstart
----------

Firstly, you must build a grammar which mexpar will use to parse input with.

```perl
# define two token rules: foo and bar
my $grammar = {
  'rules' => [
    {
      'type' => 'T_FOO',
      'pattern' => '^foo$'
    },
    {
      'type' => 'T_BAR',
      'pattern' => '^bar$'
    }
  ]
};
```

Grammars consist of token rules which define regular expressions to match a
given token.

This grammar must be prepared for use by passing it to `prepare()`. Once
prepared, `lex()` can be used to create a token list from either an array
reference pointing to an array of strings (lines), or by reading directly from a
file handle.

```perl
use Mexpar::Lexer qw(prepare lex);

prepare($grammar);

# read from an array of lines
my $input = [ ... ]; # lines
my $tokens = lex($grammar, $input);

# read from a file handle
open(my $fh, 'file.txt');
my $tokens = lex($grammar, $fh);
close($fh);
```

`lex()` returns a reference to a list of tokens identified from the input. This
token list can be passed to `parse()` for final processing.

```perl
use Mexpar::Parser qw(parse);

parse($grammar, $tokens);
```

As `parse()` processes the token list it calls handlers for each token. These
handlers are passed the token reference, the position of the token within the
token list, and the token list itself. Handlers are registered via `ontoken()`.

```perl
use Mexpar::Parser qw(ontoken);

# register a handler for the 'T_FOO' token
ontoken('T_FOO', sub {
  my $token = shift;
  my $position = shift;
  my $list = shift;  

  print "foo was here\n";
});

# register a handler for the 'T_BAR' token
sub handle_bar {
  my $token = shift;
  my $position = shift;
  my $list = shift;

  print "bar was here\n";
}
ontoken('T_BAR', \&handler_bar);
```

`ontoken()` accepts a token type as it's first argument and a subroutine
reference as it's second argument. The handler for `T_FOO` demonstrates a
registering anonymous subroutine as a handler, while `T_BAR` demonstrates
registering an existing subroutine as a handler.

Now, given the input `foobarfoo`, the output would be as follows.

```
foo was here
bar was here
foo was here
```

There's a lot more to learn about mexpar before you can start implementing your
own complex grammar, but you now have a good grasp of the fundamental setup and
workflow.

Grammar
-------

### Expressions

Expressions are handled sooner during the parse phase then regular tokens. For
example, assume you have the following input.

```
print (3 * 2)
```

Because the parser works left-to-right through the token list, it's difficult to
evaluate the expression `(3 * 2)` without performing some kind of look-ahead
in the handler for `print`. Additionally, while `print` likely only needs to
output strings and integers, it's `next` spec needs to include all expression
delimiters that could evaluate to a string or an integer. By specifying `(`
starts an expression, the parser will call it's handler first, allowing the
handler to evaluate `3 * 2` and replace the expression with a token representing
an integer instead. The handler for `print` is called after the expression has
been evaluated and can simply output the value of the integer. As well, `print`
can have a simpler `next` spec because the parser will evaluate the spec after
the expression has been replaced with the resulting value.

```perl
# non-expression next spec must include all tokens that could represents
# string or integer values after they are evanluated
my $printRule = {
    next => ['STRING', 'INTEGER', 'OPEN_PAREN', 'ROUND', 'RAND', ...],
    ...
};

# expression-based spec can include only the tokens that LITERALLY represent a
# string or integer
my $printRule = {
    next => ['STRING', 'INTEGER'],
    ...
};
```

To specify a token represents an expression, set `expression => 1` in the
token's rule.

Handlers
--------
