# $Id: 10genwrap.t,v 1.4 2004/02/24 20:25:41 jeff Exp $

use DBI;

print "1..2\n";

require 't/dbinit.pl';
my $dbh = dbinit();

# TEST 1
# test Perl.func
my $sth = $dbh->prepare("select TestPerl.func('eptest_equiv', 'MyTeSt') from dual");
if ($sth->execute) {
	my $res = ($sth->fetchrow_array)[0];
	$sth->finish;
	if ($res eq "MyTeSt") {
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
# test Perl.proc
if ($dbh->do("BEGIN TestPerl.proc('setvar', 'MyTeSt'); END;")) {
	$sth = $dbh->prepare("select TestPerl.func('getvar') from dual");
	if ($sth->execute) {
		my $res = ($sth->fetchrow_array)[0];
		$sth->finish;
		if ($res eq "MyTeSt") {
			print "ok 2\n";
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
