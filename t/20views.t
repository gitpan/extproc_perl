# $Id: 20views.t,v 1.1 2004/02/21 21:30:02 jeff Exp $

use DBI;

print "1..2\n";

require 't/dbinit.pl';
my $dbh = dbinit();

# TEST 1
# test perl_config view
my $sth = $dbh->prepare('select code_table from eptest_perl_config');
if ($sth->execute) {
	my $res = ($sth->fetchrow_array)[0];
	$sth->finish;
	if (lc($res) eq 'eptest_user_perl_source') {
		print "ok 1\n";
	}
	else {
		print "not ok 1\n";
	}
}
else {
	print "not ok 1\n";
}

# TEST 2
# test perl_status view
$sth = $dbh->prepare('select extproc_perl_version from eptest_perl_status');
if ($sth->execute) {
	my $res = ($sth->fetchrow_array)[0];
	$sth->finish;
	if ($res =~ /^extproc_perl-/) {
		print "ok 2\n";
	}
	else {
		print "not ok 2\n";
	}
}
else {
	print "not ok 2\n";
}

$dbh->disconnect;
