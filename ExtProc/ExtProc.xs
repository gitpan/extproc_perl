/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001, 2002, 2003 Jeff Horwitz (jeff@smashing.org).
 * All rights reserved.
 */

/* $Id: ExtProc.xs,v 1.10 2003/06/23 18:39:26 jeff Exp $ */

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

extern ocictx this_ctx;
extern int _connected;
typedef struct OCIExtProcContext *ExtProc__OCIExtProcContext;
typedef struct OCIEnv *ExtProc__OCIEnvHandle;
typedef struct OCISvcCtx *ExtProc__OCISvcHandle;
typedef struct OCIError *ExtProc__OCIErrHandle;

MODULE = ExtProc		PACKAGE = ExtProc		

void
exception(msg)
	char *msg;

	CODE:
	ora_exception(this_ctx.ctx, msg);

ExtProc::OCIExtProcContext
context()
	CODE:
	RETVAL = this_ctx.ctx;

	OUTPUT:
	RETVAL

void
_connected_on()
	CODE:
	_connected = 1;

void
_connected_off()
	CODE:
	_connected = 0;

int
_is_connected()
	CODE:
	RETVAL = _connected;

	OUTPUT:
	RETVAL

ExtProc::OCIEnvHandle
_envhp()
	CODE:
	RETVAL = this_ctx.envhp;

	OUTPUT:
	RETVAL

ExtProc::OCISvcHandle
_svchp()
	CODE:
	RETVAL = this_ctx.svchp;

	OUTPUT:
	RETVAL

ExtProc::OCIErrHandle
_errhp()
	CODE:
	RETVAL = this_ctx.errhp;

	OUTPUT:
	RETVAL

void
database_name()
	PREINIT:
	char res[MAX_SIMPLE_QUERY_RESULT];
	char *sql = "select ora_database_name from dual";

	PPCODE:
	simple_query(this_ctx.ctx, sql, res, 0);
	XPUSHs(sv_2mortal(newSVpv(res, PL_na)));

void
sessionid()
	PREINIT:
	char res[MAX_SIMPLE_QUERY_RESULT];
	char *sql = "select USERENV('sessionid') from dual";

	PPCODE:
	simple_query(this_ctx.ctx, sql, res, 0);
	XPUSHs(sv_2mortal(newSVpv(res, PL_na)));

void
user()
	PREINIT:
	char res[MAX_SIMPLE_QUERY_RESULT];
	char *sql = "select user from dual";

	PPCODE:
	simple_query(this_ctx.ctx, sql, res, 0);
	XPUSHs(sv_2mortal(newSVpv(res, PL_na)));

void
ep_debug(msg)
	char *msg;

	CODE:
#ifdef EP_DEBUGGING
	ep_debug(msg);
#endif /* EP_DEBUGGING */

