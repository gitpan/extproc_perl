# Oracle Perl Procedure Library
#
# Copyright (c) 2001, 2002, 2003 Jeff Horwitz (jeff@smashing.org).
# All rights reserved.

# $Id: Makefile.PL,v 1.3 2003/05/22 16:39:02 jeff Exp $

use ExtUtils::MakeMaker;

my $oh = $ENV{'ORACLE_HOME'};

WriteMakefile(
    'NAME'		=> 'ExtProc',
    'VERSION_FROM'	=> 'ExtProc.pm',
    'PREREQ_PM'		=> {},
    'LIBS'		=> [''],
    'DEFINE'		=> '',
    'INC'		=> "-I.. -I$oh/rdbms/public -I$oh/rdbms/demo",
);
