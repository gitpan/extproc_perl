# $Id: 15taint.t,v 1.2 2003/07/20 16:59:34 jeff Exp $

use DBI;
require 't/eptest.pl';

unless ($tainting) {
	print "1..0 # skip tainting not enabled\n";
	exit 0;
}

print "1..3\n";

my $dbh = my_connect();
if ($dbh) {
	print "ok 1\n";
}
else {
	print "not ok 1\n";
	exit 1;
}

$dbh->{RaiseError} = 0;
$dbh->{PrintError} = 0;

if ($dbh->do("call test_perl_p('_codetable','test_extproc_perl_code')")) {
	print "ok 2\n";
}
else {
	print "not ok 2\n";
	$dbh->disconnect;
	exit 1;
}

# this should FAIL if taint checking is enabled
if ($dbh->do("call test_perl_p('writefile','ep_test.$$')")) {
	print "not ok 3\n";
}
else {
	print "ok 3\n";
}

$dbh->disconnect;

exit 0;
