#!/usr/bin/perl

use Test::More;
use Test::Exception;

use Mexpar::Lexer qw(prepare lex);
use Mexpar::Error qw(delegate);


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


###
# Test prepare()
#

# test is grammar can be prepared
ok(!defined($grammar->{'_prepared'}), "prepare(): grammar is not already prepared");
prepare($grammar);
ok(defined($grammar->{'_prepared'}), "prepare(): prepare grammar");

# check error is raised when preparing grammar with no rules defined
my $badgrammar = {};
dies_ok { prepare($badgrammar); } "prepare(): throw error for grammar without rules";


###
# Test lex()
#

# test lex'ing from a file handle (GLOB)
open(my $fh, '<unit/LexerTest.extra') || die('failed to open LexerTest.extra');
my $tokens = lex($grammar, $fh);
is($#{$tokens}, 2, "lex(filehandle): test appropriate number of tokens returned");
is($tokens->[0]->{'type'}, 'FOO', "lex(filehandle): first token is FOO");
is($tokens->[0]->{'value'}, 'foo', "lex(filehandle): first token's value is 'foo'");
is($tokens->[1]->{'type'}, 'NL', "lex(filehandle): third token is NL");
is($tokens->[2]->{'type'}, 'EOF', "lex(filehandle): fourth token is EOF");
close($fh);

# test lex'ing an array of lines
$input = [" foo \n"];
$tokens = lex($grammar, $input);
is($#{$tokens}, 2, "lex(array): test appropriate number of tokens returned");
is($tokens->[0]->{'type'}, 'FOO', "lex(array): first token is FOO");
is($tokens->[0]->{'value'}, 'foo', "lex(array): first token's value is 'foo'");
is($tokens->[1]->{'type'}, 'NL', "lex(array): third token is NL");
is($tokens->[2]->{'type'}, 'EOF', "lex(array): fourth token is EOF");

done_testing();
