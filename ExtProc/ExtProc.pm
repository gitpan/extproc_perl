# Oracle Perl Procedure Library
#
# Copyright (c) 2001 Jeff Horwitz (jeff@smashing.org).  All rights reserved.
# This package is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.

# $Id: ExtProc.pm,v 1.9 2001/08/31 15:58:16 jhorwitz Exp $

package ExtProc;

require 5.005_62;
use strict;
use warnings;

require Exporter;
require DynaLoader;

# check for DBI & Oracle driver
eval { use DBI; };
$@ && croak("ExtProc module requires DBI");
unless (grep(/^Oracle$/, DBI->available_drivers)) {
	croak("DBI Oracle driver not found");
}

our @ISA = qw(Exporter DynaLoader);
our %EXPORT_TAGS = ( 'all' => [ qw(
	&DATABASE_NAME
	&USER
	&SESSIONID
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(
);
our $VERSION = '0.93';

bootstrap ExtProc $VERSION;

sub _simple_query {
	my ($query,@bind_vars) = @_;
	my $ctx = context();
	unless ($ctx) {
		exception("invalid OCIExtProc context");
		return undef;
	}
	my $dbh = DBI->connect('dbi:Oracle:extproc','','',{ context => $ctx });
	unless ($dbh) {
		exception("DBI->connect failed: ".$DBI::errstr);
		return undef;
	}
	my $sth = $dbh->prepare($query);
	unless ($sth) {
		exception("prepare failed".$dbh->errstr);
		return undef;
	}
	$sth->execute(@bind_vars);
	my $res = $sth->fetchall_arrayref;
	return @{$res};
}
	
sub database_name {
	my @res = _simple_query("select ora_database_name from dual");
	return $res[0][0];
}

sub user {
	my @res = _simple_query("select user from dual");
	return $res[0][0];
}

sub sessionid {
	my @res = _simple_query("select USERENV('sessionid')  from dual");
	return $res[0][0];
}

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
External Procedure Library, and requires DBI & DBD::Oracle.

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

=item context

Returns an OCIExtProcContext object for use with DBI->connect.  When connecting
to the database that called the external procedure, use the database name
'extproc', and supply no username or password.  Pass the context returned by
this function to the DBI->connect method by defining 'context' in the
attributes parameter.  Use the standard DBI method of connecting when using
another database.  An example follows:


 use DBI;
 use ExtProc;

 # get the current OCI context
 my $context = ExtProc::context;

 # connect back to the calling database
 my $dbh = DBI->connect("dbi:Oracle:extproc", "", "",
            { 'context' => $ctx });

NOTE: External procedures are stateless, so there is no concept of a persistent
connection to the database.  Therefore, you must run the DBI->connect method
before each query.  This may be automated in the future.

=back

=head1 AUTHOR

Jeff Horwitz <jeff@smashing.org>

=head1 SEE ALSO

perl(1), perlembed(1), DBI(3), DBD::Oracle(3)

=cut
