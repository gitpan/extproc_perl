/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001, 2002 Jeff Horwitz (jeff@smashing.org).
 * All rights reserved.
 *
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: ExtProc.xs,v 1.6 2002/11/20 20:43:06 jhorwitz Exp $ */

#ifdef __cplusplus
extern "C" {
#endif
#include <oci.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "extproc_perl.h"
#ifdef __cplusplus
}
#endif

extern OCIExtProcContext *this_ctx;
typedef struct OCIExtProcContext *ExtProc__OCIExtProcContext;

MODULE = ExtProc		PACKAGE = ExtProc		

void
exception(msg)
	char *msg;

	CODE:
	ora_exception(this_ctx, msg);

ExtProc::OCIExtProcContext
context()
	CODE:
	RETVAL = this_ctx;

	OUTPUT:
	RETVAL

void
database_name()
	PREINIT:
	char res[MAX_SIMPLE_QUERY_RESULT];
	char *sql = "select ora_database_name from dual";

	PPCODE:
	simple_query(this_ctx, sql, res, 0);
	XPUSHs(sv_2mortal(newSVpv(res, PL_na)));

void
sessionid()
	PREINIT:
	char res[MAX_SIMPLE_QUERY_RESULT];
	char *sql = "select USERENV('sessionid') from dual";

	PPCODE:
	simple_query(this_ctx, sql, res, 0);
	XPUSHs(sv_2mortal(newSVpv(res, PL_na)));

void
user()
	PREINIT:
	char res[MAX_SIMPLE_QUERY_RESULT];
	char *sql = "select user from dual";

	PPCODE:
	simple_query(this_ctx, sql, res, 0);
	XPUSHs(sv_2mortal(newSVpv(res, PL_na)));
