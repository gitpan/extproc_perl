/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001, 2002 Jeff Horwitz (jeff@smashing.org).
 * All rights reserved.
 *
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: simple_query.c,v 1.5 2003/04/11 15:40:02 jeff Exp $ */

#include <oci.h>
#include "extproc_perl.h"

int simple_query(OCIExtProcContext *ctx, char *sql, char *res, int silent)
{
	ocictx oci_ctx;
	ocictx *oci_ctxp = &oci_ctx;
	OCIDefine *def1;
	text out[MAX_SIMPLE_QUERY_RESULT];
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
		if (!silent) {
			ora_exception(ctx,"exec");
		}
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
		if (!silent) {
			ora_exception(ctx,"fetch");
		}
		return(err);
	}

	strncpy(res, out, MAX_SIMPLE_QUERY_RESULT);

	err = OCIHandleFree(oci_ctxp->stmtp, OCI_HTYPE_STMT);
	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"OCIHandleFree");
		}
		return(err);
	}

	return(0);
}

int simple_lob_query(OCIExtProcContext *ctx, char *sql, OCILobLocator *lobl, char *buf, int *buflen, int silent)
{
	ocictx oci_ctx;
	ocictx *oci_ctxp = &oci_ctx;
	OCIDefine *def1;
	int err, loblen, amtp;
	boolean flag;
	
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

	err = OCIDescriptorAlloc(oci_ctxp->envhp, (dvoid *)&lobl, OCI_DTYPE_LOB, 0, 0);

	err = OCIDefineByPos(oci_ctxp->stmtp,
		&def1,
		oci_ctxp->errhp,
		1,
		&lobl,
		-1,
		SQLT_CLOB,
		(dvoid *) 0,
		(dvoid *) 0,
		(dvoid *) 0,
		OCI_DEFAULT);

	err = OCIStmtExecute(oci_ctxp->svchp,
		oci_ctxp->stmtp,
		oci_ctxp->errhp,
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

	err = OCIHandleFree(oci_ctxp->stmtp, OCI_HTYPE_STMT);
	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"OCIHandleFree");
		}
		return(err);
	}

	err = OCILobLocatorIsInit(oci_ctxp->envhp, oci_ctxp->errhp, lobl, &flag);
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

	err = OCILobGetLength(oci_ctxp->svchp, oci_ctxp->errhp,
		lobl, &loblen);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		if (!silent) {
			ora_exception(ctx,"OCILobGetLength");
		}
		return(err);
	}

	amtp = loblen;
	*buflen = amtp;
	
	err = OCILobRead(oci_ctxp->svchp, oci_ctxp->errhp, lobl, &amtp, 1,
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
