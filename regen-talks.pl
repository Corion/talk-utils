#!/opt/perl/bin/perl5.8.7 -w
use strict;
use POSIX qw(strftime);
use Template;
use File::Basename;
use File::Spec;
use Cwd 'getcwd';
use Data::Dumper;
use Getopt::Long;
use File::Glob qw(bsd_glob);
use XML::Atom::SimpleFeed;

GetOptions(
    'target|t:s' => \my $target_dir,
    'force|f'    => \my $force,
    'local|l'    => \my $local_only,
    'format'     => \my @format,
    'verbose|v'  => \my $verbose,
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
    dpw2009 => '11. Deutscher Perl Workshop, Frankfurt am Main (2009)',
    gpw2009 => '11. Deutscher Perl Workshop, Frankfurt am Main (2009)',
    yapce2009 => 'YAPC::Europe 2009 (Lisbon)',
    dpw2010 => '12. Deutscher Perl Workshop, Schorndorf (2010)',
    gpw2010 => '12. Deutscher Perl Workshop, Schorndorf (2010)',
    yapce2010 => 'YAPC::Europe 2010 (Pisa)',
    froscon2010 => 'FrOSCon 2010 (St. Augustin)',
    yapce2011 => 'YAPC::Europe 2011 (Riga)',
    gpw2011 => '13. Deutscher Perl Workshop, Frankfurt (2011)',
    dpw2011 => '13. Deutscher Perl Workshop, Frankfurt (2011)',
);
my @talks = grep { -f
                && (   m!/[^-]+.(pod|slides)$!
		    || m!-talk\.(pod|slides)$!
		    || m!/(.*)/\1.(pod|slides)$!
		    || (m!/(.*)/(.*?)(?:.en)?.(pod|slides)$! && (lc basename($1) eq $2 ))) } glob '../*/*.pod ../*/*.slides';

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
    print Dumper $info;
    my $s = $info->{tags};
    if ($s) {
        for my $section (@$s) {
            $sections{ $section } ||= [];
            push @{$sections{ $section }}, $info;
        };
    } else {
        warn "Talk $info->{title} has no section";
    };
};

my @sections = map { { items => $sections{$_}, tag => $_, name => $tags{$_}} } sort keys %sections;
warn Dumper \@sections;

sub html {
    my ($params) = @_;
    my $template = Template->new();
    $template->process(\*DATA,$params, \my $index);
    return $index;
};

sub atom {
    my ($params) = @_;
    my $base_url = $params->{base};
    my $feed = XML::Atom::SimpleFeed->new(
        title   => 'Vortraege von Max Maischein',
        link    => $base_url,
        link    => { rel => 'self', href=>"$base_url/index.atom", },
        updated => strftime( '%Y-%m-%dT%H:%M:%SZ', gmtime ),
        author  => 'Max Maischein',
        id      => "$base_url/index.atom",
    );
    # flatten the sections into one long list
    for my $talk (map { @{ $_->{items} } } @{ $params->{sections} }) {
        $talk->{date} ||= strftime( '%Y-%m-%dT%H:%M:%SZ', gmtime );
        $feed->add_entry(
            title => $talk->{title},
            (link  => join '/', $base_url, $talk->{talkdir},$talk->{htmlname},),
            (id    => join '/', $base_url, $talk->{talkdir},$talk->{htmlname},),
            summary => $talk->{title},
            updated => $talk->{date}, # should fix this to be a HTTP date
            (map {; category => $_ } @{ $talk->{tags} }),
        );
    };
    return $feed->as_string
};

my $index = html({ sections => \@sections });
if ($local_only) {
    print $index;
    exit;
};
my $atom = atom({ sections => \@sections, base => 'http://corion.net/talks', });

sub upload_files {
    my ($host,$target_dir) = @_;
    for my $talk (map {@$_} values %sections) {
        my $old_dir = getcwd;
        chdir "../" . $talk->{talkdir}
            or die "Couldn't chdir to $talk->{talkdir}: $!";
        my @files = map  { -d($_) ? bsd_glob "$_/*" : $_ }
                    grep { defined and -e($_) } (
            'images',
	    'ui',
	    'ui/default',
	    'ui/i18n',
	    $talk->{htmlname},
	    $talk->{htmlname_en},
	    $talk->{podname},
        );
        
        system('ssh', $host, "mkdir","$target_dir/$talk->{talkdir}");
        system('rsync', '-arR', @files, "$host:$target_dir/$talk->{talkdir}");
        chdir( $old_dir )
            or die "Couldn't restore '$old_dir': $!";
    };
    system('ssh', $host, "chmod","-R", "ugo+rx", "$target_dir/");
};

upload_files('datenzoo.de',$target_dir);

sub r_open {
    my ($host,$remote_name) = @_;
    open my $target, "| ssh $host 'cat >$remote_name'"
        or die "Connection to '$host' failed: $!";
    $target
};

#my $html_target = r_open( 'corion.net' => "${target_dir}/index.html" );
my $html_target = r_open( 'datenzoo.de' => "${target_dir}/index.html" );
print {$html_target} $index;

my $atom_target = r_open( 'datenzoo.de' => "${target_dir}/index.atom" );
print {$atom_target} $atom;


__DATA__
<html>
<head>
<title>Vortraege von Max Maischein</title>
<link rel="stylesheet" href="../style.css"></link>
<link rel="alternate" type="application/atom+xml" href="index.atom">
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
