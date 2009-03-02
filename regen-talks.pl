#!perl -w
use strict;
use Template;
use File::Basename;
use File::Spec;
use Data::Dumper;

my %tags = (
    '' => 'Unsortierte Talks',
    dpw2009 => '11. Deutscher Perl Workshop 2009',
);
my @talks = grep { -f && /[^-]+(-talk)\.pod$/ } glob '../*/*.pod';

# All talks are assumed to be in spod5 format

sub talk_metadata {
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
    if ($meta{tags}) {
        $meta{tags} = [ split /,/, $meta{tags} ];
    };
    \%meta
};

my %sections;
for (@talks) {
    print "$_\n";
    my $info = talk_metadata( $_ );
    my $section = $info->{tags}
                ? $info->{tags}->[0]
		: '';
    $sections{ $section } ||= [];
    push @{$sections{ $section }}, $info;
};
my $template = Template->new();
my @sections = map { { items => $sections{$_}, tag => $_, name => $tags{$_}} } sort keys %sections;
$template->process(\*DATA,{ sections => \@sections });

__DATA__
<html>
<head><title>Vortraege</title></head>
<body>
[% FOR s IN sections %]
<h2>[% s.name %]</h2>
<ul>
[% FOR i IN s.items %]<li><a href="[% i.talkdir %]/[% i.htmlname %]">[% i.title %]</a></li>[% END %]
</ul>
[% END %]
</body>
</html>
