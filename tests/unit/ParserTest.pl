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
        },
        {
            type => 'BAR',
            pattern => '^bar$',
            next => 'BAZ'
        },
        {
            type => 'BAZ',
            pattern => ''
        },
        {
            type => 'BIZ',
            pattern => '^biz$',
            expression => 1
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
    my ($token, $position, $list) = @_;
    is($token, $tokens->[0], "parse(): onToken(FOO): token is correct");
    is($position, 0, "parse(): onToken(FOO): token position is correct");
    is($list, $tokens, "parse(): onToken(FOO): token list is correct");
});
parse($grammar, $tokens);


###
# Test parse() with expressions
#

# token with non-repeating subsequence
$tokens = [
    {
        type => 'BAR',
        pattern => '^bar$',
        next => ['BAZ'],
        line => 1,
        char => 0,
        value => 'bar'
    },
    {
        type => 'BIZ',
        pattern => '^biz$',
        expression => 1,
        line => 1,
        char => 3,
        value => 'biz'
    }
];

my $barCalled = 0;
ontoken('BAR', sub {
    my ($token, $position, $list) = @_;
    $barCalled++;
});
ontoken('BIZ', sub {
    my ($token, $position, $list) = @_;
    is($barCalled, 0, "parse(): expression handler called first for token with non-repeating subsequence");
    $token->{'type'} = 'BAZ',
});
parse($grammar, $tokens);
is($barCalled, 1, "parse(): token handler for token prior to expression only called once");

# token with repeating subsequence
$tokens = [
    {
        type => 'BAR',
        pattern => '^bar$',
        next => ['BAZ'],
        min => 1,
        separator => '',
        stop => 'STOP',
        line => 1,
        char => 0,
        value => 'bar'
    },
    {
        type => 'BIZ',
        pattern => '^biz$',
        expression => 1,
        line => 1,
        char => 3,
        value => 'biz'
    },
    {
        type => 'STOP',
        pattern => '^stop$',
        line => 1,
        char => 6,
        value => 'stop'
    }
];

$barCalled = 0;
ontoken('BAR', sub {
    my ($token, $position, $list) = @_;
    $barCalled++;
});
ontoken('BIZ', sub {
    my ($token, $position, $list) = @_;
    is($barCalled, 0, "parse(): expression handler called first for token with repeating subsequence");
    $token->{'type'} = 'BAZ',
});
parse($grammar, $tokens);
#is($barCalled, 1, "parse(): token handler for token prior to expression only called once");


done_testing(7);
