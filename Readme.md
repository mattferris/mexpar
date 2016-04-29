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
reference as it's second argument. The handler for `T_FOO` demonstrates
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

The rules by which mexpar parses input is dictated by a ruleset known as a
*grammar*. In the Quickstart section above, we defined a simple grammar
containing two rules defining the tokens `T_FOO` and `T_BAR`. Let's break down
the example a bit more to understand what these rules are saying.

Grammar rules are hash references containing keys, or *specifications* (specs),
for a given token. The two mandatory specs are `type` which defines the internal
name of the token, and `pattern` which specifies a regular expression which is
used to match the literal representation of the token. To reiterate,
`type => 'T_FOO'` specifies the internal name of the token and is used when
registering token handlers, while `pattern => '^foo$'` specifies the regex that
`lex()` will use to match the token.

### Capturing Token Values

In many cases, a token won't match a concrete set of characters. Say we had a
token representing a person's name. The value of the token would need to contain
the person's name, which of course would not be a static value. This is
accomplished by specifying `pattern` as follows.

```perl
pattern => '^([a-zA-Z\'-]+)$'
```

By enclosing the regex in parenthesis (a sub-pattern in regex parlance), the
value of the matched string is captured and made stored in the token for use in
token handlers.

```perl
# accessing the token's captured value from a handler
ontoken('NAME', sub {
    my $token = shift;
    print $token->{'value'};
});
```

### Global Options

There are a few global options that can be defined within a grammar. These
include defining a list of tokens to ignore during `parse()` and special tokens
that `lex()` will use for identifying the end of a line and the end of a file.

#### Ignore Certain Tokens

In many cases, it is useful to identity tokens with `lex()`, but ignore them
with `parse()`. Typically, this is whitespace tokens, but could perhaps be
punctuation in some cases as well. A list of tokens that `parse()` should ignore
can be defined in a grammar via the top-level `ignore` key. The value of
`ignore` is a regular expression matching token types.

```perl
my $grammar = {
    ignore => '^(SPACE|TAB)'
};
```

#### End-of-File & End-of-Line Tokens

mexpar automatically identifies newlines and the end of a file. These tokens are
silently excluded from resulting token list unless they are defined in the
`eol` (end-of-line) and `eof` (end-of-file) keys at the top level of the
grammar. These keys store a single token type each which will be inserted into
the token as appropriate.

```perl
my $grammar = {
    eol => 'NEWLINE',
    eof => 'EOF'
};
```

### Subsequent Tokens

A token can define which tokens must follow. In this way a grammar's syntax can
be constructed. `parse()` uses this information to determine if the syntax of a
series of tokens is valid, throwing a parse error if it isn't. This series of subsequent tokens is specified using the `next` spec, and is an array ref of
token types that satisfy the spec.

```perl
{
    type => 'FOO',
    pattern => '^foo$',
    next => ['BAR', 'BAZ|BIZ']
}
```

In the above example, the `next` spec for `FOO` can be satisfied if `FOO` is
followed by `BAR`, which is then followed by either `BAZ` *or* `BIZ`.

#### Repeating Sequences

In some cases, the subsequent tokens may reflect a repeating sequence that is
expected to repeat 0 or more times. Once the `next` spec is defined, two more
specs are used to specify how many ties the must repeat (`min`) as well as the
token that delimits the end of the sequence (`stop`). This is useful for
handling parenthesized, bracketed, or braced lists. For example:

```perl
{
    type => 'OPEN_PAREN',
    pattern => '^\($',
    next => ['FOO|BAR|BAZ'],
    mine => 1,
    stop => 'CLOSE_PAREN'
}
```

An optional separator spec can be defined which allows for each sequence to be
separated by a specific token.

```perl
{
    type => 'OPEN_PAREN',
    pattern => '^\($',
    next => ['FOO|BAR|BAZ'],
    mine => 1,
    stop => 'CLOSE_PAREN'
    separator => 'COMMA' # define the sequence separator
}
```

It is now possible to parse the following list:

```
(foo,bar,baz)
```

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

### Token Heirarchies

Handlers
--------

Handlers are the boundary between mexpar and your application. Everytime a token
is matched by the parser, any handlers that are registered for that token are
called. Handlers are registered via `ontoken()` which accepts the handler type
as it's first argument and a reference to a subroutine as it's second argument.
The preferred method of registering handlers is to use an anonymous subroutine.

```perl
# register a handler for the FOO token
ontoken('FOO', sub {
   ...    
});
```

When a handler is called, it is passed three arguments: the matched token, the
token's position in the token list, and the token list itself. These three
arguments allow the handler to perform forward and backward lookups of
surrounding tokens which can help provide context.

```perl
ontoken('FOO', sub {
    my ($token, $position, $list) = @_;

    # get the previous token in the list
    my $prevToken = $list->[$position-1];

    # get the next token in the list
    my $nextToken = $list->[$position+1];

    # get the first token in the list
    my $firstToken = $list->[0];
});
```

Multiple handlers can be registered for a single token, and will be called in
the order that they were registered.
