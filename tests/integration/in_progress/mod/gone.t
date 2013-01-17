my $test = Mod::In_Progress::Gone->new();
$test->input_file("dist/mod_mappings_source.csv");
$test->output_file("dist/mod_gone_output.csv"); 
$test->output_error_file("dist/mod_gone_errors.csv");
$test->run_tests();
exit;


package Mod::In_Progress::Gone;
use base 'IntegrationTest';

use v5.10;
use strict;
use warnings;
use Test::More;


sub test {
    my $self = shift;
    
    $self->test_closed_gones(@_);
}
