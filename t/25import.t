# $Id: 25import.t,v 1.1 2004/02/21 21:30:02 jeff Exp $

use DBI;

print "1..2\n";

require 't/dbinit.pl';
my $dbh = dbinit();

# TEST 1
# import procedure from testimport.pl
unless($dbh->do("BEGIN TestPerl.import_perl('import_equiv', 'testimport.pl'); END;")) {
	print "not ok 1\n";
	print "Bail out! import_perl failed: ", $dbh->errstr, "\n";
	exit 1;
}
print "ok 1\n";

# TEST 2
# call imported procedure
$sth = $dbh->prepare("select TestPerl.func('import_equiv', 'MyTeSt') from dual");
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

$dbh->disconnect;
