#!/usr/bin/perl

use Test::More;
use Test::Exception;

use Mexpar::Parser qw (parse ontoken);

# grammar
my $grammar = {
  ignore => '^(WS)$',
  eof => 'EOF',
  eol => 'NL',
  rules => [
    {
      type => 'WS',
      pattern => '^(\s+)$'
    },
    {
      type => 'EOF',
      pattern => '',
      value => 'EOF'
    },
    {
      type => 'NL',
      pattern => '',
      value => "\n",
    },
    {
      type => 'FOO',
      pattern => '^(foo)$',
    }
  ]
};

# token list for " foo \n"
my $tokens = [
    {
        type => 'FOO',
        pattern => '^(foo)$',
        line => 1,
        char => 2,
        value => 'foo'
    },
    {
        type => 'NL',
        pattern => '',
        line => 1,
        char => 6,
        value => "\n"
    },
    {
        type => 'EOF',
        pattern => '',
        line => 2,
        char => 1
    }
];


###
# Test parse()
#

ontoken('FOO', sub {
    my $token = shift;
    my $position = shift;
    my $list = shift;

    is($token, $tokens->[0], "parse(): onToken(FOO): token is correct");
    is($position, 0, "parse(): onToken(FOO): token position is correct");
    is($list, $tokens, "parse(): onToken(FOO): token list is correct");
});
parse($grammar, $tokens);


done_testing(3);
