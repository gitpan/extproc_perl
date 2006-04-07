# $Id: 05debug.t,v 1.1 2006/04/06 15:18:31 jeff Exp $

# test debugging

use DBI;
use Test::More tests => 4;

require 't/dbinit.pl';
my $dbh = dbinit();
my $sth;
my $file;

# Perl.debug(1)
ok ($dbh->do('BEGIN TestPerl.debug(1); END;'), 'Perl.debug(1)');

# Perl.debug(0)
ok ($dbh->do('BEGIN TestPerl.debug(0); END;'), 'Perl.debug(0)');

# debug_file
$sth = $dbh->prepare('SELECT debug_file FROM eptest_perl_status');
if ($sth && $sth->execute()) {
    $file = ($sth->fetchrow_array)[0];
    like($file, qr/\/tmp\/ep_debug.\d+/, 'debug_file');
}
else {
    fail('Perl.debug(1)');
}

# debug_file existence
ok (-e $file, 'debug_file existence');
