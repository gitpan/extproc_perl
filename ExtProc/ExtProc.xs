/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001 Jeff Horwitz (jeff@smashing.org).  All rights reserved.
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: ExtProc.xs,v 1.3 2001/08/15 20:47:41 jhorwitz Exp $ */

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

/* NEEDS REAL ERROR MESSAGES */
static int simple_text_query(OCIExtProcContext *ctx, char *sql, char *res)
{
	ocictx oci_ctx;
	ocictx *oci_ctxp = &oci_ctx;
	OCIDefine *def1;
	text out[1024];
	int err;
	
	err = OCIExtProcGetEnv(ctx,
		&oci_ctxp->envhp,
		&oci_ctxp->svchp,
		&oci_ctxp->errhp);

	if (err) {
		ora_exception(ctx,"getenv");
		return(err);
	}

	err = OCIHandleAlloc(oci_ctxp->envhp,
		(dvoid **)&oci_ctxp->stmtp,
		OCI_HTYPE_STMT,
		0,
		0);

	if (err) {
		ora_exception(ctx,"handlealloc");
		return(err);
	}

	err = OCIStmtPrepare(oci_ctxp->stmtp,
		oci_ctxp->errhp,
		(text *) sql,
		strlen(sql),
		OCI_NTV_SYNTAX,
		OCI_DEFAULT);

	if (err) {
		ora_exception(ctx,"prepare");
		return(err);
	}

	err = OCIStmtExecute(oci_ctxp->svchp,
		oci_ctxp->stmtp,
		oci_ctxp->errhp,
		0,
		0,
		NULL,
		NULL,
		OCI_DEFAULT);

	if (err) {
		ora_exception(ctx,"exec");
		return(err);
	}

	err = OCIDefineByPos(oci_ctxp->stmtp,
		&def1,
		oci_ctxp->errhp,
		1,
		&out,
		256,
		SQLT_STR,
		(dvoid *) 0,
		(dvoid *) 0,
		(dvoid *) 0,
		OCI_DEFAULT);

	err = OCIStmtFetch(oci_ctxp->stmtp,
		oci_ctxp->errhp,
		1,
		OCI_FETCH_NEXT,
		OCI_DEFAULT);

	if (err) {
		ora_exception(ctx,"fetch");
		return(err);
	}

	strncpy(res, out, 1024);

	return(0);
}

MODULE = ExtProc		PACKAGE = ExtProc		

void
database_name()
	PREINIT:
	char *name;

	PPCODE:
	New(0, name, 4000, char); /* is there a better way to estimate? */
	simple_text_query(this_ctx, "select ora_database_name from dual", name);
	XPUSHs(sv_2mortal(newSVpv(name,0)));
	Safefree(name);

void
user()
	PREINIT:
	char *user;

	PPCODE:
	New(0, user, 4000, char); /* is there a better way to estimate? */
	simple_text_query(this_ctx, "select user from dual", user);
	XPUSHs(sv_2mortal(newSVpv(user,0)));
	Safefree(user);

void
sessionid()
	PREINIT:
	char *sid;

	PPCODE:
	New(0, sid, 4000, char); /* is there a better way to estimate? */
	simple_text_query(this_ctx, "select USERENV('sessionid') from dual", sid);
	XPUSHs(sv_2mortal(newSVpv(sid,0)));
	Safefree(sid);

void
exception(msg)
	char *msg;

	CODE:
	ora_exception(this_ctx, msg);
