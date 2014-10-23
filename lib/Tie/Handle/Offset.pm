use strict;
use warnings;

package Tie::Handle::Offset;
# ABSTRACT: Tied handle that hides the beginning of a file
our $VERSION = '0.001'; # VERSION

use parent qw/Tie::StdHandle/;
use Scalar::Util qw( refaddr weaken );

#--------------------------------------------------------------------------#
# Inside-out data storage and accessor
#--------------------------------------------------------------------------#

my %HEAD_OFF = ();

sub offset {
  my $self = shift;
  if ( @_ ) {
    return $HEAD_OFF{ refaddr $self } = shift;
  }
  else {
    return $HEAD_OFF{ refaddr $self };
  }
}

# Track objects for thread-safety

my %REGISTRY = ();

#--------------------------------------------------------------------------#
# Tied handle methods
#--------------------------------------------------------------------------#

sub TIEHANDLE
{
  my $class = shift;
  my $params;
  $params = pop if ref $_[-1] eq 'HASH';

  my $self    = \do { no warnings 'once'; local *HANDLE};
  bless $self,$class;
  my $id = refaddr $self;
  weaken( $REGISTRY{ $id } = $self );
  $self->OPEN(@_) if (@_);
  if ( $params->{offset} ) {
    $HEAD_OFF{ $id } = $params->{offset};
    seek($self, $HEAD_OFF{ $id }, 0);
  }
  return $self;
}

sub TELL    {
  my $cur = tell($_[0]) - $HEAD_OFF{ refaddr $_[0] };
  # XXX shouldn't ever be less than zero, but just in case...
  return $cur > 0 ? $cur : 0;
}

sub SEEK    {
  my ($self, $pos, $whence) = @_;
  my $id = refaddr $self;
  my $rc;
  if ( $whence == 0 || $whence == 1 ) { # pos from start, cur
    $rc = seek($self, $pos + $HEAD_OFF{ $id }, $whence);
  }
  elsif ( _size($self) + $pos < $HEAD_OFF{$id} ) { # from end
    $rc = '';
  }
  else {
    $rc = seek($self,$pos,$whence);
  }
  return $rc;
}

sub OPEN
{
  my $id = refaddr $_[0];
  $HEAD_OFF{ $id } = 0;
  $_[0]->CLOSE if defined($_[0]->FILENO);
  @_ == 2 ? open($_[0], $_[1]) : open($_[0], $_[1], $_[2]);
}

sub _size {
  my ($self) = @_;
  my $cur = tell($self);
  seek($self,0,2); # end
  my $size = tell($self);
  seek($self,$cur,0); # reset
  return $size;
}

#--------------------------------------------------------------------------#
# DESTROY()
#--------------------------------------------------------------------------#

sub DESTROY {
    my $self = shift;
    delete $HEAD_OFF{ refaddr $self };
    delete $REGISTRY{ refaddr $self };
}

#--------------------------------------------------------------------------#
# CLONE()
#--------------------------------------------------------------------------#

sub CLONE {
    for my $old_id ( keys %REGISTRY ) {

        # look under old_id to find the new, cloned reference
        my $object = $REGISTRY{ $old_id };
        my $new_id = refaddr $object;

        # relocate data
        $HEAD_OFF{ $new_id } = $HEAD_OFF{ $old_id };
        delete $HEAD_OFF{ $old_id };

        # update the weak reference to the new, cloned object
        weaken ( $REGISTRY{ $new_id } = $object );
        delete $REGISTRY{ $old_id };
    }

    return;
}

1;


# vim: ts=2 sts=2 sw=2 et:

__END__
=pod

=head1 NAME

Tie::Handle::Offset - Tied handle that hides the beginning of a file

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use Tie::Handle::Offset;

  tie *FH, 'Tie::Handle::Offset', "<", $filename, { offset => 20 };

=head1 DESCRIPTION

This modules provides a file handle that hides the beginning of a file.
After opening, the file is positioned at the offset location. C<seek()> and
C<tell()> calls are modified to preserve the offset.

For example, C<tell($fh)> will return 0, though the actual file position
is at the offset.  Likewise, C<seek($fh,80,0)> will seek to 80 bytes from
the offset instead of 80 bytes from the actual start of the file.

=for Pod::Coverage method_names_here

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<http://rt.cpan.org/Public/Dist/Display.html?Name=Tie-Handle-Offset>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/dagolden/tie-handle-offset>

  git clone https://github.com/dagolden/tie-handle-offset.git

=head1 AUTHOR

David Golden <dagolden@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by David Golden.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut

