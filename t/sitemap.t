use strict;
use warnings;
use autodie;

use Test::More;

use File::Temp qw/ tempdir /;
use MetaCPAN::SiteMap;
use Try::Tiny;
use XML::Simple;

use lib './lib';

#  Test each of the three things that the production script is going to do,
#  but limit the searches to a single chunk of 250 results to speed things
#  along.

my @tests = (

    {   inputs => {
            object_type    => 'author',
            field_name     => 'pauseid',
            xml_file       => '',
            cpan_directory => 'author',
        },
        pattern => qr{https:.+/author/[A-Z-]+},
    },

    {   inputs => {
            object_type    => 'distribution',
            field_name     => 'name',
            xml_file       => '',
            cpan_directory => 'module',
        },
        pattern => qr{https:.+/module/\w+},
    },

    {   inputs => {
            object_type    => 'release',
            field_name     => 'distribution',
            xml_file       => '',
            cpan_directory => 'release',
            filter         => { status => 'latest' },
        },
        pattern => qr{https:.+/release/\w+},
    }
);

my $tempDir = tempdir( CLEANUP => 1 );

foreach my $test (@tests) {

    #  Try a bogus directory, and then a directory that exists, but that we
    #  shouldn't be able to write to, to verify that the error-checking is
    #  behaving.

    for my $bogusXMLfile (qw{ /doesntExist123/foo.xml /usr/bin/foo.xml}) {

        my (%bogus_args) = %{ $tests[0]->{inputs} };
        $bogus_args{'xml_file'} = $bogusXMLfile;

        try {
            MetaCPAN::Sitemap->new(%bogus_args)->process;
            fail('Did not fail with bad XML file path.');
        }
        catch {
            ok( 1,
                "Called with a bogus XML filename argument, caught error: $_"
            );
        };
    }

    #  Generate the XML file into a file in a temporary directory, then
    #  check that the file exists, is valid XML, and has the right number
    #  of URLs.

    my $args = $test->{'inputs'};
    $args->{'xml_file'} = File::Spec->catfile( $tempDir,
        "$test->{'inputs'}{'object_type'}.xml.gz" );

    MetaCPAN::Sitemap->new( %{$args} )->process;
    ok( -e $args->{'xml_file'},
        "XML output file for $args->{'object_type'} exists" );

    open( my $xmlFH, '<:gzip', $args->{'xml_file'} );

    my $xml = XMLin($xmlFH);
    ok( defined $xml, "XML for $args->{'object_type'} checks out" );

    ok( @{ $xml->{'url'} }, "We have some URLs to look at" );

    #  Check that each of the urls has the right pattern.

    my $count = 0;
    foreach my $url ( @{ $xml->{'url'} } ) {
        $count++;
        like( $url, $test->{'pattern'}, "URL matches" );
        last if $count == 100;
    }
}

done_testing;
