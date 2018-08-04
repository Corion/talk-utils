#!perl -w
use Win32::FileNotify;
use WWW::Mechanize::Chrome;
use Log::Log4perl ':easy';
use File::Glob ':bsd_glob';
use Path::Class 'file';

Log::Log4perl->easy_init($ERROR);

use Getopt::Long;
GetOptions(
    'v|verbose' => \my $verbose,
);

sub status($) {
    print "$_[0]\n"
        if($verbose);
};

my ($file,@cmd) = @ARGV;

if( ! @cmd ) {
    @cmd = 'gmake';
};

$file = file(bsd_glob $file);
my $watch = Win32::FileNotify->new($file->absolute);
my $mech = WWW::Mechanize::Chrome->new(
    headless => 0,
);

(my $html = $file->absolute) =~ s/\.pod$/\.html/i;

status "Loading $html";
$mech->get_local("$html");
while (1) {
    $watch->wait;
    
    system(@cmd);

    # Remember what slide of the slideshow was shown
    #my ($page,$type) = $mech->eval_in_page('snum');
    my $url = $mech->uri;
    (my $page) = $url =~ /(\d+)$/;

    status "Reloading $html";
    $mech->get_local("$html");
    
    $page ||= '0';
    status "Showing slide $url";
    $mech->eval_in_page("go($page)");
};