package Channel;
use Carp ();
use Log::TraceMessages qw(t d);

my @all;
my %idx_a; # index by Ananova id
my %idx_x; # index by XMLTV id
sub new {
    my $proto = shift;
    my $class = (ref $proto) || $proto;
    my $self = {};
    bless $self, $class;
    push @all, $self;
    return $self;
}

# Accessors for individual channel.

# Each channel can have one or more Ananova ids, but each Ananova id
# belongs to only one channel.
#
# If one channel has several Ananova ids, that means that the same
# listings are available on Ananova under two separate names.  For
# example 'Granada Plus' and 'Granada Plus - ITV Digital' are presumed
# to be the same channel, so they have a single channel entry with two
# Ananova ids.  That raises the question of which id should be used to
# calculate the display name of the channel.  Therefore the first id
# to be added can be fetched specially, and you should probably do
# things like setting the display name based only on the first id, and
# not again for all the other ids.
#
sub add_ananova_id {
    my $self = shift;
    my $id = shift;
    if (defined $idx_a{$id} and $idx_a{$id} ne $self) {
	$self->croak("a channel with Ananova id $id already exists");
    }
    ++ $self->{ananova_ids}->{$id};
    $self->{first_ananova_id} = $id
      if not defined $self->{first_ananova_id};
    $idx_a{$id} = $self;
    return $self;
}
sub get_first_ananova_id {
    my $self = shift;
    $self->croak('no Ananova ids set')
      if not defined $self->{first_ananova_id};
    return $self->{first_ananova_id};
}
sub is_ananova_id {
    my $self = shift;
    my $id = shift;
    $self->croak('ids not set') if not defined $self->{ananova_ids};
    return $self->{ananova_ids}->{$id};
}
# get_ananova_ids() not needed?

sub set_xmltv_id {
    my $self = shift;
    my $id = shift;
    for ($self->{xmltv_id}) {
	$self->croak("cannot set XMLTV id to $id, already set to $_")
	  if defined and $_ ne $id;
    }
    if (defined $idx_x{$id} and $idx_x{$id} ne $self) {
	$self->croak("a channel with XMLTV id $id already exists");
    }
    $self->{xmltv_id} = $id;
    $idx_x{$id} = $self;
    return $self;
}
sub get_xmltv_id {
    my $self = shift;

    if (not defined $self->{xmltv_id}) {
	# Invent an RFC2838-style name, if we have a definitive
	# display name to make one from.  Otherwise undef.
	#
	if (not $self->has_definitive_display_name()) {
	    return undef;
	}

	my $display = $self->get_main_display_name();
	die if not defined $display;
	my $munged = $display;
	for ($munged) {
	    tr/ _/-/s;
	    tr/a-zA-Z0-9-//cd;
	    tr/A-Z/a-z/;
	}
	my $new = "$munged.tv-listings.ananova.com";

	# We just hope that the same name was not picked for some
	# other channel.  It shouldn't be if we can trust display
	# names to be different.
	#
	$self->set_xmltv_id($new);
    }

    return $self->{xmltv_id};
}

sub set_type {
    my $self = shift;
    my $type = shift;
    for ($self->{type}) {
	$self->croak("cannot set type to $type, already set to $_")
	  if defined and $_ ne $type;
    }
    $self->{type} = $type;
    return $self;
}
sub get_type {
    my $self = shift;
    # Okay for type to be undef.
    return $self->{type};
}

# Similarly to Ananova id, region can be multivalued.
sub add_region {
    my $self = shift;
    my $region = shift;
    ++ $self->{regions}->{$region};
    return $self;
}
sub is_region {
    my $self = shift;
    my $region = shift;
    $self->croak('regions not set') if not defined $self->{regions};
    return $self->{regions}->{$region};
}
# all_regions() not needed I think.

sub set_main_display_name {
    my $self = shift;
    my ($new_name, $defin) = @_;
    if (not $defin) {
	for ($self->{main_display_name}) {
	    $self->croak("cannot set main display name to $new_name, already set to $_")
	      if defined and $_ ne $new_name;
	}
	$self->{main_display_name} = $new_name;
	$self->{main_display_name_defin} = 0;
	return $self;
    }
    else {
	for ($self->{main_display_name}) {
	    $self->croak("cannot set main display name to $new_name, definitive name already set to $_")
	      if $self->{main_display_name_defin} and $_ ne $new_name;
	}
	$self->{main_display_name} = $new_name;
	$self->{main_display_name_defin} = 1;
	return $self;
    }
}
# Add additional display names to a channel.  This is an ordered list,
# but duplicates are silently removed.
#
sub add_extra_display_names {
    my $self = shift;
    my %used;
    foreach (@{$self->{extra_display_names}}) {
	$used{$_}++ && die;
    }
    foreach (@_) {
	unless ($used{$_}++) {
	    push @{$self->{extra_display_names}}, $_;
	}
    }
    return $self;
}
sub get_display_names {
    my $self = shift;
    my $main = $self->{main_display_name};
    $self->croak('main display name not set')
      if not defined $main;
    my @r = ($main);

    # Add the extra display names to the list.  These are without
    # duplicates but we never bothered to check they didn't clash with
    # the main name.  So weed out that kind of duplication now.
    #
    my %used;
    foreach (@{$self->{extra_display_names}}) {
	die if not defined;
	die if $used{$_}++;
	if (defined and ($_ ne $main)) {
	    push @r, $_;
	}
    }
    return @r;
}
sub get_main_display_name {
    my $self = shift;
    # Okay to return undef.
    return $self->{main_display_name};
}
sub has_definitive_display_name {
    my $self = shift;
    return (defined $self->{main_display_name}) && $self->{main_display_name_defin};
}
# Get some kind of display name to show to the user in error messages.
sub get_a_display_name {
    my $self = shift;
    foreach (qw(main_display_name xmltv_id ananova_id)) {
	return $self->{$_} if defined $self->{$_};
    }
    $self->carp('channel with no name whatsoever'); return '(unknown)';
}

# Channel finding
sub find_by_ananova_id {
    my $class = shift;
    my $id = shift;
    return $idx_a{$id};
}
sub find_by_xmltv_id {
    my $class = shift;
    my $id = shift;
    return $idx_x{$id};
}
sub all {
    my $class = shift;
    return @all;
}

sub stringify {
    my $self = shift;
    my @r;
    push @r, $self->{xmltv_id} if defined $self->{xmltv_id};
    foreach (sort keys %{$self->{ananova_ids}}) {
	push @r, $_;
	last; # let's just have the first one eh?
    }
    push @r, $self->{main_display_name}
      if defined $self->{main_display_name};
    return '[' . join(', ', @r) . ']'
}

# Writing a single channel as XMLTV format.  Parameters:
#   XMLTV::Writer object
#   Language used for display names
#
sub write {
    my $self = shift;
    t 'writing channel: ' . d $self;
    my ($writer, $lang) = @_;
    my $id = $self->get_xmltv_id();
    my @names = $self->get_display_names();
    t 'writing display names: ' . d \@names;
    my @out;
    foreach (@names) {
	if (not tr/0-9//c) {
	    # Just digits, doesn't need a language.
	    push @out, [ $_ ];
	}
	else {
	    push @out, [ $_, $lang ];
	}
    }
    my %ch = ( id => $id, 'display-name' => \@out );
    t 'writing channel hash: ' . d \%ch;
    $writer->write_channel(\%ch);
}

sub croak {
    my $self = shift;
    my $msg = shift;
    Carp::croak($self->stringify() . ": $msg");
}
sub carp {
    my $self = shift;
    my $msg = shift;
    Carp::carp($self->stringify() . ": $msg");
}

1;
