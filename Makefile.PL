# Oracle Perl Procedure Library
#
# Copyright (c) 2001, 2002, 2003 Jeff Horwitz (jeff@smashing.org).
# All rights reserved.

# $Id: Makefile.PL,v 1.26 2003/07/31 22:03:03 jeff Exp $

# Makefile generator for extproc_perl

use Config;

print "Verifying configuration...\n\n";

# make sure we've set ORACLE_HOME
my $oracle_home = $ENV{'ORACLE_HOME'};
unless ($oracle_home) {
	die "Please set the ORACLE_HOME environment variable.";
}

# verify we have a shared libperl
if ($Config{'useshrplib'} ne 'yes' && $Config{'useshrplib'} ne 'true') {
	die "A shared libperl is required to build this distribution."
} 
print "You are using a shared libperl.  Good.\n";

# verify we are NOT using a threads-enabled perl
if ($Config{'usethreads'} eq 'define') {
	die "Threads-enabled Perl is not supported in this version.";
}
print "You are not using a threads-enabled Perl.  Good.\n";

# what is the path to perl?
my $perl = $Config{'perlpath'};

# what version are we using?
my $perl_version = $Config{'version'};

# what is the extension for shared libraries?
my $dlext = $Config{'dlext'};

# where to install scripts
my $script_bin = $Config{'installscript'};

# set some defaults
$DEFAULT_MODS = "IO Socket attrs Fcntl DBI DBD::Oracle";
$DEFAULT_LIBPATH = "${oracle_home}/lib";
$DEFAULT_BOOTSTRAP = "${DEFAULT_LIBPATH}/extproc_perl_boot.pl";
$DEFAULT_CODE_TABLE = "extproc_perl_code";
$DEFAULT_DEBUGGING = "no";
$DEFAULT_TAINTING = "yes";

# load config from previous run
if ( -r '.config' ) {
	eval { require '.config'; };
}
else {
	print STDERR "No cached configuration (don't worry): $!\n";
}
	
print <<_DONE_;

Oracle does not support Perl's dynamic loading of modules, so you need to
specify at compile time which modules you want to use.  This does not apply
to Perl-only modules, but you can enter them here anyway if you are unsure,
and they will be ignored.  ExtProc is automatically included, so you don't
need to specify it here.  Type "+" first if you want to add to the default
list instead of replacing it (e.g. "+Authen::Krb5 HTML::Parser").

_DONE_

print "Modules to include in this build [$DEFAULT_MODS]: ";
my $mods = <STDIN>;
chomp $mods;
unless ($mods) {
	$mods = $DEFAULT_MODS;
}
if ($mods =~ /^\+(.*)/) {
	$mods = "$DEFAULT_MODS $1";
}

print "Where should I install the extproc_perl library [${DEFAULT_LIBPATH}]: ";
my $libpath = <STDIN>;
chomp $libpath;
unless ($libpath) {
	$libpath = $DEFAULT_LIBPATH;
}

print <<_DONE_;

extproc_perl can parse a global bootstrap file that contains Perl code shared
by all sessions.  You can use it to store common subroutines or data, even
system-specific data, as it lives in the file system rather than the database.
If the file does not exist, there is no error -- all code will be read from
the database.  If you do not want this feature enabled at all, specify
/dev/null for the path below.

_DONE_

print "Path to bootstrap file [${DEFAULT_BOOTSTRAP}]: ";
my $bootfile = <STDIN>;
chomp $bootfile;
unless ($bootfile) {
	$bootfile = $DEFAULT_BOOTSTRAP;
}

print <<_DONE_;

extproc_perl will query the calling database for a Perl subroutine if it
doesn't exist in the bootstrap file.  Specify the default table to query
here.  You can change it dynamically using the special function _codetable.

_DONE_

print "Table to query [${DEFAULT_CODE_TABLE}]: ";
my $code_table = <STDIN>;
chomp $code_table;
unless ($code_table) {
	$code_table = $DEFAULT_CODE_TABLE;
}

print <<_DONE_;

The extproc_perl internal debugger will log various internal activities and
allow you to view STDERR output from your code.  This is not recommended for
production installations, as there is a performance penalty.

_DONE_

print "Would you like to enable debugging (yes/no) [${DEFAULT_DEBUGGING}]? ";
my $debugging = <STDIN>;
chomp $debugging;
unless ($debugging) {
	$debugging = $DEFAULT_DEBUGGING;
}
my $DEBUG_DEF = ($debugging =~ /^y/i) ? "-DEP_DEBUGGING" : "";

print <<_DONE_;

extproc_perl can enable taint checking which will taint all arguments to
functions and procedures.  Since your code will run as the same user that runs
the Oracle database, this is HIGHLY recommended for production environments.
If you're just experimenting with extproc_perl, you probably don't need this.
See the perlsec(1) man page for more information on tainting.

_DONE_

print "Would you like to enable taint checks (yes/no) [${DEFAULT_TAINTING}]? ";
my $tainting = <STDIN>;
chomp $tainting;
unless ($tainting) {
	$tainting = $DEFAULT_TAINTING;
}
my $TAINTING_DEF = ($tainting =~ /^y/i) ? "-DEP_TAINTING" : "";

print "Would you like to configure a database to test (yes/no) [yes]? ";
my ($dbname,$dbuser,$dbpass);
my $dotest = <STDIN>;
chomp $dotest;
if ($dotest =~ /^y/i || $dotest eq '') {
	print "What Oracle database should I run the tests on [$DEFAULT_DBNAME]? ";
	$dbname = <STDIN>;
	chomp $dbname;
	unless ($dbname) {
		$dbname = $DEFAULT_DBNAME;
	}

	print "Specify a username I can use to connect to $dbname [$DEFAULT_DBUSER]: ";
	$dbuser = <STDIN>;
	chomp $dbuser;
	unless ($dbuser) {
		$dbuser = $DEFAULT_DBUSER;
	}

	print "${dbuser}'s password on $dbname [*hidden*]: ";
	system("stty -echo");
	$dbpass = <STDIN>;
	chomp $dbpass;
	system("stty echo");
	print "\n";
	unless ($dbpass) {
		$dbpass = $DEFAULT_DBPASS;
	}

	print "Writing test configuration...\n";
	open(FILE, ">t/eptest.pl") or die $!;
	print FILE <<_DONE_;
\$db_user = '$dbuser';
\$db_pass = '$dbpass';
\$db_name = '$dbname';
\$tainting = '$TAINTING_DEF';
\$debugging = '$DEBUG_DEF';
1;

sub my_connect
{
        return DBI->connect("dbi:Oracle:\$db_name", \$db_user, \$db_pass);
}
_DONE_
	close(FILE);
}
else {
	print "Okay, but you won't be able to run any tests!\n";
	sleep 1;
}

print "Writing configuration cache...\n";
open(FILE, ">.config") or die $!;
print FILE <<_DONE_;
\$DEFAULT_MODS = '$mods';
\$DEFAULT_LIBPATH = '$libpath';
\$DEFAULT_BOOTSTRAP = '$bootfile';
\$DEFAULT_CODE_TABLE = '$code_table';
\$DEFAULT_DEBUGGING = '$debugging';
\$DEFAULT_TAINTING = '$tainting';
\$DEFAULT_DBNAME = '$dbname';
\$DEFAULT_DBUSER = '$dbuser';
\$DEFAULT_DBPASS = '$dbpass';
_DONE_
close(FILE);

my $CC = $Config{'cc'};
my $LD = $Config{'ld'};
my $LDDLFLAGS = $Config{'lddlflags'};
my $OPT = $Config{'optimize'};

print "\nWriting Makefile...\n";

rename("Makefile","Makefile.old");
open(FILE,">Makefile") or die "couldn't open Makefile for writing: $!";
print FILE <<_DONE_;
# AUTO-GENERATED BY Makefile.PL -- DO NOT EDIT!

CC=${CC}
LD=${LD}
OPT=${OPT}
PERL=${perl}
ORACLE_HOME=${oracle_home}
MODULES=ExtProc ${mods}
CPPFLAGS=-I. -I\$(ORACLE_HOME)/rdbms/demo -I\$(ORACLE_HOME)/rdbms/public -DPERL_VERSION_STRING=\\"${perl_version}\\" -DBOOTSTRAP_FILE=\\"${bootfile}\\" -DCODE_TABLE=\\"${code_table}\\" -DSTATIC_MODULES="\\"\$(MODULES)\\"" $DEBUG_DEF $TAINTING_DEF

OBJS=extproc_perl.o perlxsi.o simple_query.o

all: extproc_perl.${dlext} ep

perlxsi.c:
	\$(PERL) -MExtUtils::Embed -e xsinit -- -o STDOUT -std \$(MODULES) | grep -v boot_DynaLoader > \$@

ExtProc.a: extproc_perl.h ExtProc/ExtProc.xs
	(cd ExtProc ; \$(MAKE))
	cp -f ExtProc/blib/arch/auto/ExtProc/ExtProc.a .

.c.o:
	\$(CC) \$(CPPFLAGS) `\$(PERL) -MExtUtils::Embed -e ccopts` \$(OPT) -c \$<

extproc_perl.${dlext}: \$(OBJS) ExtProc.a
	\$(LD) -o \$@ `\$(PERL) -MExtUtils::Embed -e ldopts` ${LDDLFLAGS} \$(OBJS) `PERL=\$(PERL) sh gen_module_libs \${MODULES}` ExtProc.a

ep:	ep.in
	\$(PERL) -p -e 's#\\\@PERL\\\@#\$(PERL)#' ep.in > ep && chmod 555 ep
	
install: all
	cp extproc_perl.${dlext} ${libpath} && chmod 555 ${libpath}/extproc_perl.${dlext}
	cp ep ${script_bin} && chmod 555 ${script_bin}/ep
	(cd ExtProc ; \$(MAKE) install)

clean:
	rm -f *.o extproc_perl.${dlext} ep ExtProc.a perlxsi.c Makefile t/eptest.pl
	(cd ExtProc ; \$(MAKE) clean)

distclean: clean
	rm -f Makefile.old .config
	(cd ExtProc ; \$(MAKE) realclean ; rm -f Makefile.old)

test:	all
	PERL_DL_NONLAZY=1 \$(PERL) -e 'use Test::Harness qw(&runtests); runtests \@ARGV;' t/*.t
_DONE_

print "Configuring ExtProc module\n";
system("cd ExtProc ; ${perl} Makefile.PL DEFINE='${DEBUG_DEF} ${TAINTING_DEF}'");
print "Done.\n";
