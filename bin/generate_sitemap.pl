#!/usr/bin/env perl

#  Generate the sitemap XML files for the robots.txt file.

use strict;
use warnings;

use FindBin qw ($Bin);
use lib "$Bin/../lib";

use MetaCPAN::Sitemap;

my @ROGUE_DISTRIBUTIONS
    = qw(kurila perl_debug perl-5.005_02+apache1.3.3+modperl pod2texi perlbench spodcxx);

my @parts = (

    #  For authors, we're looking for the pauseid, and want to build a URL
    #  with 'author' in the path.

    {   object_type    => 'author',
        field_name     => 'pauseid',
        xml_file       => '/tmp/authors.xml.gz',
        cpan_directory => 'author',
    },

    #  For distributions, we're looking for the module name, and we
    #  want to build a URL with 'module' in the path. Filter definition lifted
    #  from iCPAN.pm.

    {   object_type    => 'file',
        field_name     => 'name',
        xml_file       => '/tmp/modules.xml.gz',
        cpan_directory => 'module',
        filter         => {
            and => [
                {   -not_filter => {
                            or => [
                                map {
                                    { term => { 'file.distribution' => $_ } }
                                } @ROGUE_DISTRIBUTIONS
                            ]
                        }
                },
                { term => { status => 'latest' } },
                {   or => [

                        # we are looking for files that have no authorized
                        # property (e.g. .pod files) and files that are
                        # authorized
                        { missing => { field => 'file.authorized' } },
                        { term => { 'file.authorized' => \1 } },
                    ]
                },
                {   or => [
                        {   and => [
                                { exists => { field => 'file.module.name' } },
                                { term => { 'file.module.indexed' => \1 } }
                            ]
                        },
                        {   and => [
                                { exists => { field => 'documentation' } },
                                { term => { 'file.indexed' => \1 } }
                            ]
                        }
                    ]
                },
            ]
        }
    },

    #  For releases, we're looking for a download URL; since we're not
    #  building a URL, the cpan_directory is missing, but we also want to
    #  filter on only the 'latest' entries.

    {   object_type    => 'release',
        field_name     => 'distribution',
        xml_file       => '/tmp/releases.xml.gz',
        cpan_directory => 'release',
        filter         => { status => 'latest' },
    }
);

MetaCPAN::Sitemap->new($_)->process for @parts;
