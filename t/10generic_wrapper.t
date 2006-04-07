# $Id: 10generic_wrapper.t,v 1.2 2006/04/07 17:30:35 jeff Exp $

# test generic wrappers

use DBI;
use Test::More tests => 4;

require 't/dbinit.pl';
my $dbh = dbinit();
my $sth;
my $tmp;

# generic function noargs
undef $tmp;
$sth = $dbh->prepare("SELECT TestPerl.func('ep_generic_func_noargs') from dual");
if ($sth && $sth->execute()) {
    $tmp = ($sth->fetchrow_array)[0];
}
is($tmp, 'testing 1 2 3', 'generic function noargs');

# generic function 1 arg
undef $tmp;
$sth = $dbh->prepare("SELECT TestPerl.func('ep_generic_func_1arg', 'testing 1 2 3') from dual");
if ($sth && $sth->execute()) {
    $tmp = ($sth->fetchrow_array)[0];
}
is($tmp, 'testing 1 2 3', 'generic function 1 arg');

# generic procedure noargs
ok($dbh->do("BEGIN TestPerl.proc('ep_generic_proc_noargs'); END;"), 'generic procedure no args');

# generic procedure 1 arg
ok ($dbh->do("BEGIN TestPerl.proc('ep_generic_proc_1arg', 'testing 1 2 3'); END;"), 'generic_procedure 1 arg');
