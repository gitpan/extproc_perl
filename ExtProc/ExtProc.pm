# Oracle Perl Procedure Library
#
# Copyright (c) 2001 Jeff Horwitz (jeff@smashing.org).  All rights reserved.
# This package is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.

# $Id: ExtProc.pm,v 1.5 2001/08/20 20:10:12 jhorwitz Exp $

package ExtProc;

require 5.005_62;
use strict;
use warnings;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);
our %EXPORT_TAGS = ( 'all' => [ qw(
	&DATABASE_NAME
	&USER
	&SESSIONID
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(
);
our $VERSION = '0.91';

bootstrap ExtProc $VERSION;

sub DATABASE_NAME { database_name(@_); }
sub USER { user(@_); }
sub SESSIONID { sessionid(@_); }

1;
__END__

=head1 NAME

ExtProc - Perl interface to the Oracle Perl External Procedure Library

=head1 SYNOPSIS

  use ExtProc;

=head1 DESCRIPTION

The ExtProc module provides several functions that return useful data from
an Oracle database connection.  It is only useful from the Oracle Perl
External Procedure Library.

=head1 FUNCTIONS

=over 4

=item database_name or DATABASE_NAME (exportable)

Returns the name of the database the client is connected to.

=item user or USER (exportable)

Returns the username used to connect to Oracle.

=item sessionid or SESSIONID (exportable)

Returns the session ID of the current connection

=item exception(message)

Throws a user-defined Oracle exception.  Note that the Perl subroutine will
probably complete after this function is called, but no return values should
be accepted by the calling client.

=back 4

=head1 AUTHOR

Jeff Horwitz <jeff@smashing.org>

=head1 SEE ALSO

perl(1), perlembed(1)

=cut
