#!perl -w
use Win32::FileNotify;
#use HTML::Display;
#use HTML::Display::MozRepl;
use WWW::Mechanize::Firefox;
use File::Glob qw(bsd_glob);

use Getopt::Long;
GetOptions(
    'v|verbose' => \my $verbose,
);

sub status($) {
    print "$_[0]\n"
        if($verbose);
};

my ($file,@cmd) = @ARGV;
if( ! -f $file ) {
    ($file)= bsd_glob( $file );
};
my $watch = Win32::FileNotify->new($file);
my $mech = WWW::Mechanize::Firefox->new();

(my $html = $file) =~ s/\.pod$/\.html/i;

status "Loading $html";
$mech->get_local($html, basedir => '.');
while (1) {
    $watch->wait;
    system(@cmd);

    # Remember what slide of the slideshow was shown
    my ($page,$type) = $mech->eval_in_page('snum');

    status "Reloading $html";
    $mech->get_local($html, basedir => '.');
    
    $page ||= '0';
    status "Showing slide $page";
    $mech->eval_in_page("go($page);");
};