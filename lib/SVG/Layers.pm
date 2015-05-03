package SVG::Layers;
use strict;

sub get_layers {
    my ($file) = @_;
    my $s = SVG::File->load($file);

    my $counter = 1;
    my @result;

    for my $slide ($s->animation_from_layers) {
        (my $outname = $file) =~ s/\.svg$//gi;
        $outname .= sprintf "-%02d.svg", $counter++;
        $slide->save($outname);
        push @result, $outname;
    }
    @result
}

package SVG::File;
use strict;
use XML::LibXML;

sub svg { $_[0]->{svg} };

sub new {
    my ($class,$document) = @_;
    bless {
        svg => $document,
    }, $class
}

sub load {
    my ($class,$filename,%args) = @_;
    my $p = XML::LibXML->new();
    my $self = $class->new($p->parse_file($filename));
}

sub save {
    my ($self,$outname) = @_;
    open my $fh, ">", $outname
        or die "Couldn't create '$outname': $!";
    binmode $fh, ':utf8';
    print {$fh} $self->svg->toString;
}

sub find {
    my ($self,$xpath,$doc) = @_;
    $doc ||= $self->svg->documentElement;
    my $i = $doc->findnodes($xpath);
    $i->get_nodelist;
}

sub background {
    my ($self) = @_;
    #$self->find('/svg/g[not matches(@"inkscape:label","^layer"]');
    #$self->find('/svg/g');
    ()
}

sub layers {
    my ($self,$doc) = @_;
    $doc ||= $self->svg->documentElement;
    my @l = $self->find('/svg:svg/svg:g[@inkscape:groupmode="layer"]',$doc);
    my %label;
    for (@l) {
        ($label{ $_ }) = map { $_->value } $self->find('@inkscape:label',$_);
    }
    sort { $label{$a} cmp $label{$b} } @l
};

sub dimensions {
    my ($self) = @_;
    my ($w,$h) = map { $_->string_value } $self->find('/svg:svg@width'),$self->find('/svg:svg@height')
}

sub clone_document {
    my ($self,$org) = @_;
    $org ||= $self->svg;
    my $doc = XML::LibXML::Document->createDocument(
        $org->version,
        $org->encoding,
    );
    my $clone = $org->documentElement->cloneNode(1);
    #$doc->importNode( $clone ) or die;
    $doc->setDocumentElement( $clone );
    $doc
}

sub animation_from_layers {
    my ($self) = @_;
    my $class = ref $self;
    
    my $svg = $self->clone_document;
    my @layers = $self->layers($svg);
    $_->unbindNode for @layers;
    #my @background = $self->background($svg);

    # Remove all animation layers from the clone

    my @result;
    # Save that as the first animation step
    #push @result, $class->new( $svg );
    
    # Now add each layer into a new document
    for my $layer (@layers) {
        $svg->documentElement->appendChild($layer) or die "Couldn't append child node";
        push @result, $class->new( $svg );
        $svg = $self->clone_document($svg);
    }
    @result
}

1;