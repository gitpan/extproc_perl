/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001, 2002 Jeff Horwitz (jeff@smashing.org).
 * All rights reserved.
 *
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: simple_query.c,v 1.6 2003/04/22 01:41:19 jeff Exp $ */

#include <oci.h>
#include <EXTERN.h>
#include <perl.h>
#include "extproc_perl.h"

extern ocictx this_ctx;
extern int _connected;

/* int ep_OCIExtProcGetEnv(OCIExtProcContext *ctx)
 * wrapper around oracle's OCIExtProcGetEnv
 * we can't call getenv twice in the same transaction, so we need to save
 * our handles for later use by DBI
 */
int ep_OCIExtProcGetEnv(OCIExtProcContext *ctx)
{
	int err;

	dTHX;

	if (!_connected) {
		err = OCIExtProcGetEnv(ctx, &this_ctx.envhp,
			&this_ctx.svchp, &this_ctx.errhp);
		if (err == OCI_SUCCESS || err == OCI_SUCCESS_WITH_INFO) {
			/* be VERY careful here with threading
			   when it's supported */
			this_ctx.ctx = ctx;
			_connected = 1;
		}
	}
	else {
		err = OCI_SUCCESS;
	}
	return(err);
}

/* used for ExtProc module convenience functions */
int simple_query(OCIExtProcContext *ctx, char *sql, char *res, int silent)
{
	OCIDefine *def1;
	text out[MAX_SIMPLE_QUERY_RESULT];
	int err;
	
	ocictx *this_ctxp = &this_ctx;

	err = ep_OCIExtProcGetEnv(ctx);

	if (err) {
		ora_exception(ctx,"getenv");
		return(err);
	}

	err = OCIHandleAlloc(this_ctxp->envhp,
		(dvoid **)&this_ctxp->stmtp,
		OCI_HTYPE_STMT,
		0,
		0);

	if (err) {
		ora_exception(ctx,"handlealloc");
		return(err);
	}

	err = OCIStmtPrepare(this_ctxp->stmtp,
		this_ctxp->errhp,
		(text *) sql,
		strlen(sql),
		OCI_NTV_SYNTAX,
		OCI_DEFAULT);

	if (err) {
		ora_exception(ctx,"prepare");
		return(err);
	}

	err = OCIStmtExecute(this_ctxp->svchp,
		this_ctxp->stmtp,
		this_ctxp->errhp,
		0,
		0,
		NULL,
		NULL,
		OCI_DEFAULT);

	if (err) {
		if (!silent) {
			ora_exception(ctx,"exec");
		}
		return(err);
	}

	err = OCIDefineByPos(this_ctxp->stmtp,
		&def1,
		this_ctxp->errhp,
		1,
		&out,
		256,
		SQLT_STR,
		(dvoid *) 0,
		(dvoid *) 0,
		(dvoid *) 0,
		OCI_DEFAULT);

	err = OCIStmtFetch(this_ctxp->stmtp,
		this_ctxp->errhp,
		1,
		OCI_FETCH_NEXT,
		OCI_DEFAULT);

	if (err) {
		if (!silent) {
			ora_exception(ctx,"fetch");
		}
		return(err);
	}

	strncpy(res, out, MAX_SIMPLE_QUERY_RESULT);

	err = OCIHandleFree(this_ctxp->stmtp, OCI_HTYPE_STMT);
	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"OCIHandleFree");
		}
		return(err);
	}

	return(0);
}

/* this one is used to fetch code from the database */
int simple_lob_query(OCIExtProcContext *ctx, char *sql, OCILobLocator *lobl, char *buf, int *buflen, int silent)
{
	ocictx *this_ctxp = &this_ctx;
	OCIDefine *def1;
	int err, loblen, amtp;
	boolean flag;
	
	err = ep_OCIExtProcGetEnv(ctx);

	if (err) {
		ora_exception(ctx,"getenv");
		return(err);
	}

	err = OCIHandleAlloc(this_ctxp->envhp,
		(dvoid **)&this_ctxp->stmtp,
		OCI_HTYPE_STMT,
		0,
		0);

	if (err) {
		ora_exception(ctx,"handlealloc");
		return(err);
	}

	err = OCIStmtPrepare(this_ctxp->stmtp,
		this_ctxp->errhp,
		(text *) sql,
		strlen(sql),
		OCI_NTV_SYNTAX,
		OCI_DEFAULT);

	if (err) {
		ora_exception(ctx,"prepare");
		return(err);
	}

	err = OCIDescriptorAlloc(this_ctxp->envhp, (dvoid *)&lobl, OCI_DTYPE_LOB, 0, 0);

	err = OCIDefineByPos(this_ctxp->stmtp,
		&def1,
		this_ctxp->errhp,
		1,
		&lobl,
		-1,
		SQLT_CLOB,
		(dvoid *) 0,
		(dvoid *) 0,
		(dvoid *) 0,
		OCI_DEFAULT);

	err = OCIStmtExecute(this_ctxp->svchp,
		this_ctxp->stmtp,
		this_ctxp->errhp,
		1,
		0,
		NULL,
		NULL,
		OCI_DEFAULT);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"exec");
		}
		return(err);
	}

	err = OCIHandleFree(this_ctxp->stmtp, OCI_HTYPE_STMT);
	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"OCIHandleFree");
		}
		return(err);
	}

	err = OCILobLocatorIsInit(this_ctxp->envhp, this_ctxp->errhp, lobl, &flag);
	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"OCILobLocatorIsInit");
		}
		return(err);
	}

	if (!flag) {
		if (!silent) {
			ora_exception(ctx,"LOB locator is not initialized");
		}
		return(err);
	}

	err = OCILobGetLength(this_ctxp->svchp, this_ctxp->errhp,
		lobl, &loblen);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"OCILobGetLength");
		}
		return(err);
	}

	amtp = loblen;
	*buflen = amtp;
	
	err = OCILobRead(this_ctxp->svchp, this_ctxp->errhp, lobl, &amtp, 1,
		(dvoid *)buf, (loblen < MAX_SIMPLE_QUERY_RESULT ?
		loblen : MAX_SIMPLE_QUERY_RESULT), 0, 0, 0, SQLCS_IMPLICIT);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"OCILobGetLength");
		}
		return(err);
	}

	buf[amtp]='\0';

	return(OCI_SUCCESS);
}
