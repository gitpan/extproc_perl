# $Id: 00sqlcreate.t,v 1.6 2003/07/20 16:59:20 jeff Exp $

print "1..6\n";

use Cwd;
my $home = getcwd;

use DBI;
require 't/eptest.pl';

my $code = "use lib \"$home/ExtProc\";\n" . q{
	use DBI;
	use ExtProc;

	sub double
	{
		return $_[0] * 2;
	}

	sub var
	{
		my $value = shift;
		if (defined($value)) {
			$a = $value;
		}
		else {
			return $a;
		}
	}

	sub dbname
	{
		my $dbh = ExtProc->dbi_connect;
		my $sth = $dbh->prepare("select ora_database_name from dual");
		$sth->execute();
		my $res = ($sth->fetchrow_array())[0];
		$sth->finish;
		return $res;
	}

	sub writefile
	{
		my $fname = shift;
		open(FILE, ">>/tmp/$fname");
		print FILE "foo\n";
		close(FILE);
	}
};

my $dbh = my_connect();
if ($dbh) {
	print "ok 1\n";
}
else {
	print "not ok 1\n";
	exit 1;
}

# create test library
if ($dbh->do("CREATE OR REPLACE LIBRARY TEST_PERL_LIB IS '$home/extproc_perl.so'")) {
	print "ok 2\n";
}
else {
	print "not ok 2\n";
	$dbh->disconnect;
	exit 1;
}

# create function entry point
if ($dbh->do("CREATE OR REPLACE FUNCTION test_perl (sub IN VARCHAR2, arg1 in VARCHAR2 default NULL, dummy in VARCHAR2 default NULL) RETURN STRING AS EXTERNAL NAME \"ora_perl_func\" LIBRARY \"TEST_PERL_LIB\" WITH CONTEXT PARAMETERS ( CONTEXT, RETURN INDICATOR BY REFERENCE, sub string, arg1 string, arg1 INDICATOR short, dummy string, dummy INDICATOR short);")) {
	print "ok 3\n";
}
else {
	print "not ok 3\n";
	$dbh->disconnect;
	exit 1;
}

# create procedure entry point
if ($dbh->do("CREATE OR REPLACE PROCEDURE test_perl_p (sub IN VARCHAR2, arg1 in VARCHAR2 default NULL, dummy in VARCHAR2 default NULL) AS EXTERNAL NAME \"ora_perl_proc\" LIBRARY \"TEST_PERL_LIB\" WITH CONTEXT PARAMETERS ( CONTEXT, sub string, arg1 string, arg1 INDICATOR short, dummy string, dummy INDICATOR short);")) {
	print "ok 4\n";
}
else {
	print "not ok 4\n";
	$dbh->disconnect;
	exit 1;
}

# create code table
$dbh->{'RaiseError'} = 0;
$dbh->{'PrintError'} = 0;
$dbh->do("DROP TABLE test_extproc_perl_code");
$dbh->{'RaiseError'} = 1;
$dbh->{'PrintError'} = 1;
if ($dbh->do("CREATE TABLE test_extproc_perl_code ( code CLOB )")) {
	print "ok 5\n";
}
else {
	print "not ok 5\n";
	$dbh->disconnect;
	exit 1;
}

# insert code into code table
if ($dbh->do("insert into test_extproc_perl_code (code) values('$code')")) {
	print "ok 6\n";
}
else {
	print "not ok 6\n";
	$dbh->disconnect;
	exit 1;
}


$dbh->disconnect;
exit 0;
