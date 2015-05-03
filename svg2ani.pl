#!/usr/bin/perl -w
use strict;
use lib 'c:/Dokumente und Einstellungen/Corion/Desktop/Talks/lib';
use FindBin;
use lib $FindBin::Bin . '/lib';
use lib './lib';
use SVG::Layers;
use File::DosGlob qw(bsd_glob);
use File::Spec;
use File::Basename;

use Getopt::Long;
GetOptions(
    'o|outdir:s' => \my $outdir,
);
@ARGV = map { glob $_ } @ARGV;

my $inkscape = "C:\\Programme\\Inkscape\\inkscape.exe";
for my $file (@ARGV) {
    my $ts = -M $file;
    print "$file\n";
    my @output = SVG::Layers::get_layers($file);
    if( $outdir ) {
        $outdir = File::Spec->rel2abs($outdir,'.');
    };
    
    for my $file (@output) {
        $file = File::Spec->rel2abs($file,'.');
        (my $png = $file) =~ s/\.svg/.png/i;
        
        if( $outdir ) {
            $png = File::Spec->catfile( $outdir, basename( $png ) );
        };
        
        if( ! -e $png or $ts > -M $file ) {
            my $cmd = qq{$inkscape --export-png "$png" "$file"};
            print "[$cmd]\n";
            system($cmd) == 0
                or die "Couldn't convert $file to $png: $!/$?\n";
            print "=> $png\n";
        };
    }
    
}
