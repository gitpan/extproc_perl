# $Id: testboot.pl,v 1.4 2004/02/25 23:23:33 jeff Exp $

# test bootstrap file

use ExtProc;
use DBI;

my $var;

sub eptest_equiv
{
	return $_[0];
}

sub dbname
{
	my $e = ExtProc->new;
	my $dbh = $e->dbi_connect;
	my $sth = $dbh->prepare('select ora_database_name from dual');
	$sth->execute;
	my $user = ($sth->fetchrow_array);
	$sth->finish;
	return $user;
}

sub setvar
{
	$var = $_[0];
}

sub getvar
{
	return $var;
}

# test OUT parameters
sub eptest_add
{
	my ($n1, $n2, $res) = @_;
	${$res} = $n1 + $n2;
}

# test IN OUT parameters
sub eptest_double
{
	my $n = shift;
	${$n} *= 2;
}
