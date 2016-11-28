#!perl -w
use Win32::FileNotify;
#use HTML::Display;
#use HTML::Display::MozRepl;
use WWW::Mechanize::Firefox;
use File::Glob qw(bsd_glob);
use File::Spec;

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

if( ! -f $file ) {
    ($file)= bsd_glob( $file );
};
my $watch = Win32::FileNotify->new($file);
my $mech = WWW::Mechanize::Firefox->new();

(my $html = $file) =~ s/\.pod$/\.html/i;

if( -f $html ) {
    status "Loading $html";
    $mech->get_local($html, basedir => '.');
};

status "Watching $file";
while (1) {
    if( -f $html ) {
        $watch->wait;
    };
    system(@cmd);

    # Remember what slide of the slideshow was shown
    my ($loc,$type) = $mech->eval_in_page('window.location.toString()');
    warn "<<$loc>>";
    if( $loc !~ /#slide(\d+)/ ) {
        my ($page,$type) = eval { $mech->eval_in_page('snum') };

        status "Reloading $html";
        $mech->get_local($html, basedir => '.');

        $page ||= '0';
        status "Showing slide $page";
        $mech->eval_in_page("go($page);");
    } else {
        # We have a location we can jump to:
        status "Reloading $loc";
        $mech->get('about:blank');
        $mech->get($loc);
    }
};