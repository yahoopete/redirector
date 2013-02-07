package Mappings::LocationConfig;

use strict;
use warnings;
use base 'Mappings::Rules';



sub actual_nginx_config {
    my $self = shift;

    return $self->location_config();
}


sub location_config {
    my $self = shift;
        
    my $config_or_error_type = 'location';
    my $duplicate_entry_key  = $self->{'old_url_parts'}{'host'} . $self->{'old_url_parts'}{'path'};
    my $suggested_link_type;
    my $suggested_link;
    my $archive_link;
    my $config;
    
    # remove %-encoding in source mappings for nginx
    my $old_url = $self->{'old_url_parts'}{'path'};
    $old_url =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    
    # escape characters with regexp meaning
    $old_url =~ s{\(}{\\(}g;
    $old_url =~ s{\)}{\\)}g;
    $old_url =~ s{\.}{\\.}g;
    $old_url =~ s{\*}{\\*}g;
    
    # escape charaters with nginx config meaning
    $old_url =~ s{ }{\\ }g;
    $old_url =~ s{\t}{\\\t}g;
    $old_url =~ s{;}{\\;}g;
    
    # strip trailing slashes, as they are added as optional in nginx
    $old_url =~ s{/$}{};
    
    # escape characters with nginx config meaning in the destination
    my $new_url = $self->{'new_url'};
    $new_url =~ s{;}{\\;}g;
    
    if ( defined $self->{'duplicates'}{$duplicate_entry_key} ) {
        $config_or_error_type = 'duplicate_entry_error';
        $config = "$self->{'old_url'}\n";
    }
    elsif ( '410' eq $self->{'status'} ) {
        $config = "location ~* ^${old_url}/?\$ { return 410; }\n";
        $suggested_link_type = 'location_suggested_link';
        $suggested_link = $self->get_suggested_link( $self->{'old_url_parts'}{'path'}, 0 );
        $archive_link = $self->get_archive_link( $self->{'old_url_parts'}{'path'} );
    }
    elsif ( '301' eq $self->{'status'} ) {
        $config = "location ~* ^${old_url}/?\$ { return 301 $new_url; }\n";
    }
    
    $self->{'duplicates'}{$duplicate_entry_key} = 1;
        
    return(
        $self->{'old_url_parts'}{'host'},
        $config_or_error_type,
        $config,
        $suggested_link_type,
        $suggested_link,
        $archive_link
    );
}

1;
