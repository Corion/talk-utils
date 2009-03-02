#!/usr/bin/perl -w
use strict;
use File::Find::Rule;
use File::Spec;

my $inkscape = qq{C:\\Programme\\Inkscape\\inkscape.exe};
my $svgs = File::Find::Rule->file->name('*.svg');

my @files = grep { -f } @ARGV;
my @dirs = grep { -d } @ARGV;

push @files, $svgs->in(@dirs);

$|++;
for my $file (map { File::Spec->rel2abs($_, '.')} @files) {
    print $file;
    (my $target_base = $file) =~ s/\.svg$//i;
    my $target = $target_base . '.eps';
    my $cmd = qq{"$inkscape" -D "--export-eps=$target" --export-text-to-path --without-gui "$file"};
    #system($cmd)==0
    #    or die "Couldn't run [$cmd]: $?/$!";

    $target = $target_base . '.png';
    $cmd = qq{"$inkscape" -C "--export-png=$target" --export-text-to-path --without-gui "$file"};
    system($cmd)==0
        or die "Couldn't run [$cmd]: $?/$!";

    print "\n";
};