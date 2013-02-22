#!/usr/bin/env perl

#
# c14n.pl - canonicalise first two urls in input csv
#

use v5.10;
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;

require 'lib/c14n.pl';

my $titles;
my $allow_query_string;
my $help;

GetOptions(
  "allow-query-string|q"  => \$allow_query_string,
  'help|?' => \$help,
) or pod2usage(1);

pod2usage(2) if ($help);

while (<STDIN>) {
  chomp;

  unless ($titles) {
    $titles = $_;
    say $titles;
    next;
  }

  my @fields = split(/,/);
  $fields[0] = c14n_url($fields[0], $allow_query_string);
  $fields[1] = c14n_url($fields[1], $allow_query_string);

  say join(',', @fields);
}

__END__

=head1 NAME

c14n - canonicalise the first two columns in the input csv

=head1 SYNOPSIS

./tools/c14n.pl [options] < input

Options:

    -q, --allow-query-string    allow query-string in Old Urls
    -?, --help                  print usage

=cut
