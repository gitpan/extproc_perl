# $Id: 20debug.t,v 1.2 2003/07/20 16:59:34 jeff Exp $

use DBI;
require 't/eptest.pl';

unless ($debugging) {
	print "1..0 # skip debugging not enabled\n";
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

my $sth = $dbh->prepare("select test_perl('_enable_debug') from dual");
$sth->execute();
my $debugfile = ($sth->fetchrow_array)[0];
$sth->finish;
if ($debugfile =~ /ep_debug/) {
	print "ok 2\n";
}
else {
	print "not ok 2\n";
}

if ($dbh->do("call test_perl_p('_disable_debug')")) {
	print "ok 3\n";
}
else {
	print "not ok 3\n";
}

$dbh->disconnect;

exit 0;
