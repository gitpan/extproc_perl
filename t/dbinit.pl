# $Id: dbinit.pl,v 1.1 2004/02/21 21:30:02 jeff Exp $

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
	return $dbh;
}
