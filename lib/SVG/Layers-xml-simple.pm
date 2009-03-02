package SVG::Layers;
use strict;

sub get_layers {
    my ($file) = @_;
    my $s = SVG::File->load($file);

    my $counter = 1;
    my @result;

    for my $slide ($s->animation_from_layers) {
        (my $outname = $file) =~ s/\.svg$//gi;
        $outname .= sprintf "-%s.svg", $counter++;
        $slide->save($outname);
        push @result, $outname;
    }
    @result
}

sub get_dimensions {
    my ($file) = @_;
}

package SVG::File;
use strict;
use XML::Simple;
use Storable 'dclone';

sub svg { $_[0]->{svg} };

sub load {
    my ($class,$filename,%args) = @_;
    my $self = $class->from_structure(XMLin($filename));
}

sub save {
    my ($self,$outname) = @_;
    open my $fh, ">", $outname
        or die "Couldn't create '$outname': $!";
    print {$fh} XMLout( $self->svg, RootName => 'svg', );
}

sub background {
    my ($self) = @_;
    #grep {!/^layer/i} sort keys %{$self->svg->{g}};
    grep { $self->svg->{g}->{$_}->{'inkscape:label'} !~ /^layer/i } keys %{$self->svg->{g}};
}

sub layers {
    my ($self) = @_;
    my @l = 
        sort { $self->svg->{g}->{$a}->{'inkscape:label'} cmp $self->svg->{g}->{$b}->{'inkscape:label'}}
        grep { $self->svg->{g}->{$_}->{'inkscape:label'} =~ /^layer/i } keys %{$self->svg->{g}};
    @l
};

sub dimensions {
    my ($self) = @_;
    ($self->svg->{width}, $self->svg->{height})
}

sub from_structure {
    my ($class,$data,%args) = @_;
    my $self = {
        svg => $data,
        %args,
    };
    bless $self, $class;
    $self
}

sub animation_from_layers {
    my ($self) = @_;
    my @layers = $self->layers;
    my @background = $self->background;
    
    warn "Background: [@background]\n";
    
    my @result;
    my $svg = dclone $self->svg;
    my %output;
    my $class = ref $self;
    my $groups = delete $svg->{g};
    @output{@background} = @{$groups}{ @background };
    $svg->{g} = \%output;
    push @result, $class->from_structure( dclone $svg );
    for my $layer (@layers) {
        $output{ $layer } = $groups->{ $layer };
        push @result, $class->from_structure( dclone $svg );
    }
    @result
}

1;