#!perl -w
use strict;
use Template;
use File::Basename;
use File::Spec;
use Data::Dumper;
use Getopt::Long;
use File::Glob qw(bsd_glob);

GetOptions(
    'target|t:s' => \my $target_dir,
    'force|f'    => \my $force,
    'local|l'    => \my $local_only,
    'format'     => \my @format,
);

if (! @format) {
    @format = qw(html rss atom);
};
@format = map { split /,/ } @format;

$target_dir ||= 'corion.net/talks';


my %tags = (
    '' => undef,
    dpw2003 => '5. Deutscher Perl Workshop (2003)',
    dpw2005 => '7. Deutscher Perl Workshop (2005)',
    dpw2006 => '8. Deutscher Perl Workshop (2006)',
    dpw2007 => '9. Deutscher Perl Workshop (2007)',
    dpw2008 => '10. Deutscher Perl Workshop (2008)',
    dpw2009 => '11. Deutscher Perl Workshop (2009)',
    yapce2009 => 'YAPC::Europe 2009 (Lisbon)',
);
my @talks = grep { -f
                && (   m!/[^-]+.(pod|slides)$!
		    || m!-talk\.(pod|slides)$!
		    || m!/(.*)/\1.(pod|slides)$!
		    || (m!/(.*)/(.*).(pod|slides)$! && (lc basename($1) eq $2 ))) } glob '../*/*.pod ../*/*.slides';

# All talks are assumed to be in spod5 format

sub pod_metadata {
    my ($talk) = @_;
    open my $fh, '<', $talk
        or die "Couldn't open '$talk': $!";
    my $htmlname = lc basename $talk;
    $htmlname =~ s/\.pod/\.html/;
    my $talkdir = dirname $talk;
    $talkdir =~ s!^..[\\/]!!;
    my %meta = (
        podname => basename($talk),
        htmlname => $htmlname,
        talkdir => $talkdir,
	map { s/\s+$//; /^=meta (\w+)\s+(.*)$/ ? ($1 => $2) : () } <$fh>
    );
    (my $en_name = $htmlname) =~ s/\.html$/.en.html/i;
    if (-e "../$talkdir/$en_name") {
        $meta{htmlname_en} = $en_name;
    };
    if ($meta{tags}) {
        $meta{tags} = [ split /,/, $meta{tags} ];
    };
    \%meta
};

sub slides_metadata {
    my ($talk) = @_;
    open my $fh, '<', $talk
        or die "Couldn't open '$talk': $!";
    my $htmlname = lc basename $talk;
    $htmlname =~ s/\.slides/\.html/;
    my $talkdir = dirname $talk;
    $talkdir =~ s!^..[\\/]!!;
    my %meta = (
        podname => basename($talk),
        htmlname => $htmlname,
        talkdir => $talkdir,
	map { s/\s+$//; /^(\w+):\s+(.*)$/ ? ($1 => $2) : () } <$fh>
    );
    if ($meta{tags}) {
        $meta{tags} = [ split /,/, $meta{tags} ];
    };
    \%meta
};

my %sections;
for (@talks) {
    my $info = /\.pod/
             ? pod_metadata( $_ )
             : slides_metadata( $_ )
	     ;
    next unless $info->{title};
    my $section = $info->{tags}
                ? $info->{tags}->[0]
		: '';
    if ($section) {
        $sections{ $section } ||= [];
        push @{$sections{ $section }}, $info;
    } else {
        warn "Talk $info->{title} has no section";
    };
};
my $template = Template->new();
my @sections = map { { items => $sections{$_}, tag => $_, name => $tags{$_}} } sort keys %sections;
$template->process(\*DATA,{ sections => \@sections }, \my $index);

if ($local_only) {
    print $index;
    exit;
};

for my $talk (map {@$_} values %sections) {
    chdir "../" . $talk->{talkdir}
        or die "Couldn't chdir to $talk->{talkdir}: $!";
    my @files = map  { -d($_) ? bsd_glob "$_/*" : $_ }
                grep { -e($_) } (
        'images',
	'ui',
	'ui/default',
	'ui/i18n',
	$talk->{htmlname},
	$talk->{podname},
    );
    
    system('ssh', "corion.net", "mkdir","$target_dir/$talk->{talkdir}");
    system('rsync', '-arR', @files, "corion.net:$target_dir/$talk->{talkdir}");
};
system('ssh', "corion.net", "chmod","-R", "ugo+rx", "$target_dir/");

open my $target, "| ssh corion.net 'cat >${target_dir}/index.html'"
    or die "Connection to corion.net failed: $!";
print {$target} $index;

__DATA__
<html>
<head>
<title>Vortraege von Max Maischein</title>
<link rel="stylesheet" href="../style.css"></link>
</head>
<body>
<h1>Vortraege von Max Maischein</h1>
<p>Die meisten der folgenden Vortr&auml;ge habe ich auf den
<a href="http://www.perlworkshop.de/">Deutschen Perl Workshop</a>s gehalten.</p>
[% FOR s IN sections %]
<h2>[% s.name %]</h2>
<ul>
[% FOR i IN s.items %]<li><a href="[% i.talkdir %]/[% i.htmlname %]">[% i.title %]</a>[%
 IF i.htmlname_en; THEN %] (<a href="[% i.talkdir %]/[% i.htmlname_en %]">English</a>)[% END %]</li>[% END %]
</ul>
[% END %]
<p><a href="/">Zur&uuml;ck zur Startseite</a></p>
</body>
</html>
