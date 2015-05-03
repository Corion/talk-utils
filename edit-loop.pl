#!perl -w
use Win32::FileNotify;
#use HTML::Display;
#use HTML::Display::MozRepl;
use WWW::Mechanize::Firefox;
use File::Glob qw(bsd_glob);

use Getopt::Long;
GetOptions(
    'v|verbose' => \my $verbose,
    'f|file:s' => \my @files,
);

sub status($) {
    print "$_[0]\n"
        if($verbose);
};

my ($file,@cmd) = @ARGV;
push @files, $file;
@files = map { bsd_glob $_ } @files;
$file= $files[0];

if(0 == @cmd and -f 'Makefile') {
    @cmd = 'dmake';
};

my $watch = Win32::FileNotify->new($file);
my $mech = WWW::Mechanize::Firefox->new();

(my $html = $file) =~ s/\.pod$/\.html/i;

if( -f $html ) {
    status "Loading $html";
    $mech->get_local($html, basedir => '.');
};

status "Watchcing $file";
while (1) {
    if( -f $html ) {
        $watch->wait;
    };
    system(@cmd);

    # Remember what slide of the slideshow was shown
    my ($page,$type) = $mech->eval_in_page('snum');

    status "Reloading $html";
    $mech->get_local($html, basedir => '.');
    
    $page ||= '0';
    status "Showing slide $page";
    $mech->eval_in_page("go($page);");
};