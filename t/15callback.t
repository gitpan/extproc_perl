# $Id: 15callback.t,v 1.3 2004/02/21 21:30:02 jeff Exp $

use DBI;

print "1..2\n";

require 't/dbinit.pl';
my $dbh = dbinit();

# TEST 1
# test callback query
my $sth = $dbh->prepare("select TestPerl.func('dbname') from dual");
if ($sth->execute) {
	my $res = ($sth->fetchrow_array)[0];
	$sth->finish;
	if (lc($res) eq lc($ENV{'ORACLE_SID'})) {
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
# test callback DML
if ($dbh->do("insert into EPTEST_TABLE values('MyTeSt')")) {
	$sth = $dbh->prepare("select junk from EPTEST_TABLE");
	if ($sth->execute) {
		my $res = ($sth->fetchrow_array)[0];
		$sth->finish;
		if ($res eq "MyTeSt") {
			print "ok 2\n";
			$dbh->do("delete from EPTEST_TABLE");
		}
		else {
			print "not ok 2\n";
		}
	}
	else {
		print "not ok 2\n";
	}
}
else {
	print "not ok 2\n";
}

$dbh->disconnect;
