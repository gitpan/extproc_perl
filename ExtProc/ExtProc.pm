# Oracle Perl Procedure Library
#
# Copyright (c) 2001, 2002, 2003 Jeff Horwitz (jeff@smashing.org).
# All rights reserved.

# $Id: ExtProc.pm,v 1.24 2003/07/30 19:01:55 jeff Exp $

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
	&ep_debug
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(
);
our $VERSION = '1.03';

bootstrap ExtProc $VERSION;

sub DATABASE_NAME { database_name(@_); }
sub USER { user(@_); }
sub SESSIONID { sessionid(@_); }

# wrapper around DBI->connect so we don't call OCIExtProcGetEnv twice
# expects DBI to be loaded already
sub dbi_connect
{
	my $dbh;

	if (_is_connected()) {
		$dbh = DBI->connect('dbi:Oracle:extproc', '', '',
			{ 'ora_context' => context(),
			  'ora_envhp' => _envhp(),
			  'ora_svchp' => _svchp(),
			  'ora_errhp' => _errhp()
			}
		);
	}
	else {
		$dbh = DBI->connect('dbi:Oracle:extproc', '', '',
			{ 'ora_context' => context() } );

		# need to set this even if we fail, cuz GetEnv should succeed
		# even if the connect fails -- a little risky, but what the hay
		_connected_on();
	}

	return $dbh;
}

1;
__END__

=head1 NAME

ExtProc - Perl interface to the Oracle Perl External Procedure Library

=head1 SYNOPSIS

  use ExtProc;

=head1 DESCRIPTION

The ExtProc module provides several functions that return useful data from
an Oracle database connection.  It is only useful from the Oracle Perl
External Procedure Library (extproc_perl).

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

=item context -- DEPRECATED

If you are familiar with the pre-0.97 method of using DBI callbacks, see
dbi_connect for more information.

=item dbi_connect()

 use DBI;
 use ExtProc;

 # connect back to the calling database
 my $dbh = ExtProc->dbi_connect();

NOTE: External procedures are stateless, so there is no concept of a persistent
connection to the database.  Therefore, you must run the ExtProc->dbi_connect
method once per transaction.

=item ep_debug(message)

If debugging is enabled, write the specified message to the debug log.

=back

=head1 AUTHOR

Jeff Horwitz <jeff@smashing.org>

=head1 SEE ALSO

perl(1), perlembed(1), DBI(3), DBD::Oracle(3)

=cut
