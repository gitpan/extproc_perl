# Oracle Perl Procedure Library
#
# Copyright (c) 2001, 2002 Jeff Horwitz (jeff@smashing.org).
# All rights reserved.
#
# This package is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself.

# $Id: Makefile.PL,v 1.2 2002/11/18 01:29:43 jhorwitz Exp $

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
