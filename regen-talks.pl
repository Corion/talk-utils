#!/opt/perl-5.18/bin/perl -w
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
use Time::Piece;
use Net::SSH2; # well, we could also shell out, but that's slower
use OpenOffice::OODoc::Meta;

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


my @tags = (
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
    gpw2012 => '14. Deutscher Perl Workshop, Erlangen (2012)',
    dpw2012 => '14. Deutscher Perl Workshop, Erlangen (2012)',
    yapce2012 => 'YAPC::Europe 2012 (Frankfurt)',
    fosdem2013 => 'FOSDEM 2013 (Brussels)',
    gpw2013 => '15. Deutscher Perl Workshop, Berlin (2013)',
    dpw2013 => '15. Deutscher Perl Workshop, Berlin (2013)',
    yapce2013 => 'YAPC::Europe 2013 (Kiew / Kyiv)',
    gpw2014 => '16. Deutscher Perl Workshop, Hannover (2014)',
    dpw2014 => '16. Deutscher Perl Workshop, Hannover (2014)',
    yapce2014 => 'YAPC::Europe 2014 (Sofia)',
    apw2014 => '&Ouml;sterreichischer Perl Workshop, Salzburg (2014)',
    gpw2015 => '17. Deutscher Perl Workshop, Dresden (2015)',
    dpw2015 => '17. Deutscher Perl Workshop, Dresden (2015)',
    yapce2015 => 'YAPC::Europe 2015 (Granada)',
    gpw2016 => '18. Deutscher Perl Workshop, N&uuml;rnberg (2016)',
    dpw2016 => '18. Deutscher Perl Workshop, N&uuml;rnberg (2016)',
    yapce2016 => 'YAPC::Europe 2016 (Cluj)',
    lpw2016 => 'London Perl Workshop 2016',
    dpw2017 => '19. Deutscher Perl Workshop, Hamburg (2017)',
    gpw2017 => '19. Deutscher Perl Workshop, Hamburg (2017)',
    yapce2017 => 'YAPC::Europe 2017 (Amsterdam)',
    lpw2017 => 'London Perl Workshop 2017',
    gpw2018 => '20. Deutscher Perl Workshop, K&ouml;ln (2018)',
    tpc2018 => 'The Perl Conference in Glasgow (2018)',
    gpw2019 => '21. Deutscher Perl Workshop, M&uuml;nchen (2019)',
    dpw2019 => '21. Deutscher Perl Workshop, M&uuml;nchen (2019)',
);
my %tags = map {$tags[$_*2] => $tags[$_*2+1]} 0..($#tags / 2);
my @section_order = map {$tags[ $_*2 ]} 0..($#tags/2);

chdir( dirname $0 )
    or die sprintf "Couldn't chdir to '%s': $!", dirname($0);
my @talks = grep { -f
                && (   m!/[^-]+.(pod|slides)$!
                    || m!-talk\.(pod|slides)$!
                    || m!/(.*)/\1.(pod|slides)$!
                    || m!/(.*)/LT-\1.(md)$!i
                    || (m!/(.*)/(.*?)(?:.en|.de)?.(pod|slides)$! && (lc basename($1) eq $2 ))
                    || m!/(.*)/(.*)\.(odp)$!i ) }
            glob '../*/*.pod ../*/*.slides ../*/*.md ../*/*.odp';

# Reject todo.pod
@talks = grep { lc($_) !~ /\btodo.pod$/ } @talks;

if( $verbose ) {
    warn $_
        for @talks;
};
# All talks are assumed to be in spod5 format

sub pod_metadata {
    my ($talk) = @_;
    open my $fh, '<', $talk
        or die "Couldn't open '$talk': $!";
    my $htmlname = lc basename $talk;
    if( $talk =~ /\.md$/ ) {
        $htmlname = 'index.html';
    } else {
        $htmlname =~ s/\.pod/\.html/;
    }
    my $talkdir = dirname $talk;
    $talkdir =~ s!^..[\\/]!!;
    my %meta = (
        podname => basename($talk),
        htmlname => $htmlname,
        talkdir => $talkdir,
	map { s/\s+$//; /^=meta\s+(\w+)\s+(.*)$/ ? ($1 => $2) : () } <$fh>
    );
    (my $en_name = $htmlname) =~ s/(?:.de)?\.html$/.en.html/i;
    if (-e "../$talkdir/$en_name") {
        $meta{htmlname_en} = $en_name;
    };
    if ($meta{tags}) {
        $meta{tags} = [ split /[, ]+/, $meta{tags} ];
    };
    if( $meta{video} ) {
        my @videos;
        while( $meta{ video }=~ /L<(?:([^>|]*)\|?)([^>]+)>/g ) {
            my $title= "$1 video" || 'video';
            my $link= $2;
            my $embed;
            if( $link =~ m!/watch\?v=(.*)! ) {
                $embed= $1;
            };
            push @videos, {
                title => $title,
                link => $link,
                embed => $embed,
            };
        };
        $meta{ video }= \@videos;
    };
    if( $meta{ presdate }) {
        # reconstruct a sane date
        my $old = $meta{ presdate };
        $meta{ presdate } =~ s!M.+rz!Maerz!g;
        $meta{ presdate } =~ s!M&auml;rz!Maerz!g;
        $meta{ presdate } =~ s!Maerz!March!;
        $meta{ presdate } =~ s!\bFebruar\b!February!;
        $meta{ presdate } =~ s!\bMai\b!May!;
        $meta{ presdate } =~ s!\bJuni\b!June!;
        $meta{ presdate } =~ s!\bOktober\b!October!;
        $meta{ presdate } =~ s!\bDezember\b!December!;
        $meta{ presdate } =~ s![. ]!!g;
        $meta{ presdate } =~ s!^0!!;
        eval {
            $meta{ presdate } = Time::Piece->new->strptime($meta{presdate}, '%d%B%Y')->ymd;
            $meta{ presdate } .= '+00:00Z';
        };
        if( $@ ) {
            warn "$meta{presdate}: $@";
            $meta{ presdate } = $old;
        } else {
            #warn "OK: $old => $meta{presdate}";
        }
    };
    \%meta
};

sub markdown_metadata {
}

sub ooo_metadata {
    my( $talk) = @_;
    my $doc = OpenOffice::OODoc::Meta->new(file => $talk);
    my $talkdir = dirname $talk;
    $talkdir =~ s!^..[\\/]!!;
    warn $_ for $doc->keywords;
    my %meta = (
        podname => basename($talk),
        htmlname => basename($talk),
        htmlname_en => basename($talk),
        talkdir  => $talkdir,
        title    => $doc->title,
        #presdate => $doc->title,
        tags     => [ $doc->keywords ],
    );
    \%meta
}

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
        $meta{tags} = [ split /[, ]+/, $meta{tags} ];
    };
    \%meta
};

my %sections;
for (@talks) {
    my $info = /\.pod$/ ? pod_metadata( $_ ) 
             : /\.odp$/ ? ooo_metadata( $_ )
             :            slides_metadata( $_ )
         ;
    if( ! $info->{title} ) {
        warn "$_ has no title\n" if $verbose;
        next
    };
    #print Dumper $info;
    my $s = $info->{tags};
    if ($s) {
        for my $section (@$s) {
warn "[[$section]]";
            $sections{ $section } ||= [];
            push @{$sections{ $section }}, $info;
        };
    } else {
        warn "Talk $info->{title} has no section";
    };
};

my @sections = map { { items => $sections{$_}, tag => $_, name => $tags{$_}} }
               grep { warn $_ unless exists $sections{$_}; exists $sections{ $_ }} @section_order;

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
        $talk->{date} ||= $talk->{presdate} || strftime( '%Y-%m-%dT%H:%M:%SZ', gmtime );
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
my $atom = atom({ sections => \@sections, base => 'https://corion.net/talks', });

my $ssh;
sub ssh {
    my $host = shift;
    if( ! $ssh ) {
        #$ssh = Net::SSH2->new(debug => 1);
        $ssh = Net::SSH2->new();
#warn "Connecting to $host";
        $ssh->connect( $host ) or $ssh->die_with_error;
        $ssh->auth_agent('corion');
    };
    my $ch = $ssh->channel();
#warn "@_";
    $ch->exec( @_ );
}

sub upload_files {
    my ($host,$target_dir) = @_;
    for my $talk (map {@$_} values %sections) {
        my $old_dir = getcwd;
        chdir "../" . $talk->{talkdir}
            or die "Couldn't chdir to $talk->{talkdir}: $!";
        my @files = map  { -d($_) ? bsd_glob "$_/*" : $_ }
                    grep { defined and -e($_) } (
            'images',
            'diagrams',
            'ui',
            'ui/default',
            'ui/i18n',
            $talk->{htmlname},
            $talk->{htmlname_en},
            $talk->{podname},
        );
        
        ssh( $host, sprintf qq{mkdir "$target_dir/%s"}, quotemeta $talk->{talkdir});
        system('rsync', '-arR', @files, "$host:$target_dir/$talk->{talkdir}") == 0
           or die "rsync error: $?/$!";
        chdir( $old_dir )
            or die "Couldn't restore '$old_dir': $!";
    };
    ssh( $host, "chmod","-R", "ugo+rx", "$target_dir/");
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
<a href="http://www.perlworkshop.de/">Deutschen Perl Workshop</a>s
oder <a href="http://yapc.eu/">YAPC::Europe</a> gehalten.</p>
[% FOR s IN sections %]
<h2>[% s.name %]</h2>
<ul>
[% FOR i IN s.items %]<li><a href="[% i.talkdir %]/[% i.htmlname %]">[% i.title %]</a>
[% IF i.htmlname_en; THEN %] (<a href="[% i.talkdir %]/[% i.htmlname_en %]">English</a>)[% END %]
[% IF i.video; THEN %] ([% FOR v IN i.video %]<a href="[% v.link %]">[% v.title %]</a>[% END %])
[% FOR v IN i.video %]
[% IF v.embed; THEN %]
    [% IF NOT embedded; THEN %]
    [% SET embedded=1 %]
<iframe id="ytplayer" type="text/html" width="640" height="390"
  src="http://www.youtube.com/embed/[% v.embed %]"
  frameborder="0" allowfullscreen></iframe>
    [% END %]
[% END %]
[% END %]
[% END %]
</li>[% SET embedded=0 %][% END %]
</ul>
[% END %]
<p><a href="/">Zur&uuml;ck zur Startseite</a></p>
</body>
</html>
