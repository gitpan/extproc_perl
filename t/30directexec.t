# $Id: 30directexec.t,v 1.1 2004/02/25 23:24:05 jeff Exp $

use DBI;

print "1..6\n";

require 't/dbinit.pl';
my $dbh = dbinit();
local $dbh->{RaiseError} = 0;
local $dbh->{PrintError} = 0;

# TEST 1
# create wrapper for eptest_equiv()
unless($dbh->do("BEGIN TestPerl.create_wrapper('eptest_equiv(x IN VARCHAR2) RETURN VARCHAR2', 'TEST_PERL_LIB'); END;")) {
	print "not ok 1\n";
	print "Bail out! create_wrapper failed: ", $dbh->errstr, "\n";
	exit 1;
}

my $sql;
{
	open(FILE, "t/eptest_equiv.sql") or die $!;
	local $/;
	$sql = <FILE>;
	close(FILE);
}
# chop off SQL*Plus slash
$sql =~ s%^/%%m;

unless($dbh->do($sql)) {
	print "not ok 1\n";
	print "Bail out! CREATE failed: ", $dbh->errstr, "\n";
	exit 1;
}
print "ok 1\n";

# TEST 2
# create wrapper for add_proc()
unless($dbh->do("BEGIN TestPerl.create_wrapper('add_proc(n1 IN PLS_INTEGER, n2 IN PLS_INTEGER, sum OUT PLS_INTEGER)', 'TEST_PERL_LIB'); END;")) {
	print "not ok 1\n";
	print "Bail out! create_wrapper failed: ", $dbh->errstr, "\n";
	exit 1;
}
print "ok 2\n";

# TEST 3
# create wrapper for add_func()
unless($dbh->do("BEGIN TestPerl.create_wrapper('add_func(n1 IN PLS_INTEGER, n2 IN PLS_INTEGER) RETURN PLS_INTEGER', 'TEST_PERL_LIB'); END;")) {
	print "not ok 3\n";
	print "Bail out! create_wrapper failed: ", $dbh->errstr, "\n";
	exit 1;
}
print "ok 3\n";

# relink
$dbh->disconnect;
system("make -f perlxsi.mk test");

# reconnect
$dbh = dbinit();
local $dbh->{RaiseError} = 0;
local $dbh->{PrintError} = 0;

# TEST 4
# test eptest_equiv
if ($sth = $dbh->prepare("select eptest_equiv('MyTeSt') from dual")) {
	if ($sth->execute) {
		my $res = ($sth->fetchrow_array)[0];
		$sth->finish;
		if ($res eq "MyTeSt") {
			print "ok 4\n";
		}
		else {
			print "not ok 4\n";
		}
	}
	else {
		print "not ok 4\n";
	}
}
else {
	print "not ok 4\n";
}

# TEST 5
# test add_func
print "not ok 5 # TODO relink from test scripts\n";

# TEST 6
# test add_proc
print "not ok 6 # TODO relink from test scripts\n";

$dbh->disconnect;
