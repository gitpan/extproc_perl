# $Id: dbinit.pl,v 1.2 2004/04/11 21:05:29 jeff Exp $

# connect to database and initialize test environment

my $dbname = $ENV{'ORACLE_SID'};
my $dbuser = $ENV{'ORACLE_USERID'};

sub dbinit
{
	my $dbh = DBI->connect("dbi:Oracle:$dbname", $dbuser);
	unless ($dbh) {
		print "Bail out! DBI->connect failed: $DBI::errstr\n";
		exit 1;
	}

	unless ($dbh->do('BEGIN TestPerl.test; END;')) {
		print "Bail out! Failed to initialize test environment: ",
			$dbh->errstr, "\n";
	}

	# FOR DEVELOPMENT: enable debugging & tracing
	# $dbh->do('BEGIN TestPerl.debug(1); END;');
	# $dbh->do('alter session set sql_trace true');

	return $dbh;
}
