# $Id: 05func.t,v 1.1 2003/07/07 20:52:58 jeff Exp $

print "1..3\n";

use DBI;
require 't/eptest.pl';

my $dbh = my_connect();
if ($dbh) {
	print "ok 1\n";
}
else {
	print "not ok 1\n";
	exit 1;
}

if ($dbh->do("call test_perl_p('_codetable','test_extproc_perl_code')")) {
	print "ok 2\n";
}
else {
	print "not ok 2\n";
	$dbh->disconnect;
	exit 1;
}

my $sth = $dbh->prepare("select test_perl('double', 5) from dual");
$sth->execute();
my $res = ($sth->fetchrow_array)[0];
$sth->finish;
if ($res == 10) {
	print "ok 3\n";
}
else {
	print "not ok 3\n";
}

$dbh->disconnect;

exit 0;
