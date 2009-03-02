#!/usr/bin/perl -w
use strict;
use lib 'c:/Dokumente und Einstellungen/Corion/Desktop/Talks/lib';
use SVG::Layers;
use File::DosGlob qw(bsd_glob);
use File::Spec;

@ARGV = map { glob $_ } @ARGV;

my $inkscape = "C:\\Programme\\Inkscape\\inkscape.exe";

for my $file (@ARGV) {
    print "$file\n";
    my @output = SVG::Layers::get_layers($file);
    
    for my $file (@output) {
        $file = File::Spec->rel2abs($file,'.');
        (my $png = $file) =~ s/\.svg/.png/i;
        my $cmd = qq{$inkscape --export-png "$png" "$file"};
        system($cmd) == 0
            or die "Couldn't convert $file to $png: $!/$?\n";
        print "=> $png\n";
    }
    
}