# $Id: 15import.t,v 1.2 2006/04/07 17:30:35 jeff Exp $

# test importing

use DBI;
use Test::More tests => 3;

require 't/dbinit.pl';
my $dbh = dbinit();
my $sth;
my $tmp;

# import_perl
ok($dbh->do("BEGIN TestPerl.import_perl('ep_testimport'); END;"), 'import_perl');

# execute
undef $tmp;
$sth = $dbh->prepare("SELECT TestPerl.func('ep_testimport', 'testing 1 2 3') FROM dual");
if ($sth && $sth->execute()) {
   $tmp = ($sth->fetchrow_array)[0];
}
is($tmp, 'testing 1 2 3', 'execute');

# drop_perl
ok($dbh->do("BEGIN TestPerl.drop_perl('ep_testimport'); END;")); 
