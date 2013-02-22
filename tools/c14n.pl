#!/usr/bin/env perl

#
# c14n.pl - canonicalise first url in input csv
#

use v5.10;
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Text::CSV;

require 'lib/c14n.pl';

my $titles;
my $allow_query_string;
my $help;

GetOptions(
  "allow-query-string|q"  => \$allow_query_string,
  'help|?' => \$help,
) or pod2usage(1);

pod2usage(2) if ($help);

my $csv = Text::CSV->new( { binary => 1 } ) or die "Cannot use Text::CSV";
$csv->eol("\n");

while (my $row = $csv->getline(*STDIN)) {
  unless ($titles) {
    $titles = "found";
    $csv->print(*STDOUT, $row);
    next;
  }

  $row->[0] = c14n_url($row->[0], $allow_query_string);
  $csv->print(*STDOUT, $row);
}

__END__

=head1 NAME

c14n - canonicalise the first column in the input csv

=head1 SYNOPSIS

./tools/c14n.pl [options] < input

Options:

    -q, --allow-query-string    allow query-string in Old Urls
    -?, --help                  print usage

=cut
