# $Id: Makefile.PL,v 1.1 2003/10/10 17:09:58 jeff Exp $

use ExtUtils::MakeMaker;

my $oh = $ENV{'ORACLE_HOME'};

WriteMakefile(
	'NAME'		=> 'ExtProc',
	'VERSION_FROM'	=> 'ExtProc.pm',
	'PREREQ_PM'	=> {},
	'LIBS'		=> [''],
	'DEFINE'	=> '',
	'INC'		=> "-I.. -I$oh/rdbms/public -I$oh/rdbms/demo",
	'LINKTYPE'	=> 'static',
);
