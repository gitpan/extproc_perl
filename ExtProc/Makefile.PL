# Oracle Perl Procedure Library
#
# Copyright (c) 2001 Jeff Horwitz (jeff@smashing.org).  All rights reserved.
# This package is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.

# $Id: Makefile.PL,v 1.1 2001/08/15 18:24:59 jhorwitz Exp $

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
