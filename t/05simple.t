# $Id: 05simple.t,v 1.3 2004/02/21 21:30:02 jeff Exp $

use DBI;

print "1..1\n";

require 't/dbinit.pl';
my $dbh = dbinit();

# TEST 1
# test Perl.version -- the easiest call into the library
my $sth = $dbh->prepare('select TestPerl.version from dual');
if ($sth->execute) {
	my $res = ($sth->fetchrow_array)[0];
	$sth->finish;
	if ($res =~ /^extproc_perl-/) {
		print "ok 1\n";
	}
	else {
		print "not ok 1\n";
	}
}
else {
	print "not ok 1\n";
}

$dbh->disconnect;
