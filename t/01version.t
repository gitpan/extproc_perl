# $Id: 01version.t,v 1.3 2003/07/20 17:29:07 jeff Exp $

print "1..2\n";

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

my $sth = $dbh->prepare("select test_perl('_version') from dual");
$sth->execute();
my $res = ($sth->fetchrow_array)[0];
$sth->finish;
if ($res =~ /^extproc_perl \d+\.\d+/) {
	print "ok 2\n";
}
else {
	print "not ok 2\n";
}

$dbh->disconnect;

exit 0;
