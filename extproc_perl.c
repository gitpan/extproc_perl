/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001 Jeff Horwitz (jeff@smashing.org).  All rights reserved.
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: extproc_perl.c,v 1.7 2001/08/20 19:59:29 jhorwitz Exp $ */

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <time.h>
#include <oci.h>
#include <EXTERN.h>
#include <perl.h>
#include "extproc_perl.h"
#ifdef __cplusplus
}
#endif

#define EXTPROC_PERL_VERSION	"0.91"

static PerlInterpreter *perl;
OCIExtProcContext *this_ctx; /* for ExtProc module */

void ora_exception(OCIExtProcContext *ctx, char *msg)
{
	char str[1024];

	snprintf(str, 1023, "PERL EXTPROC ERROR: %s\n", msg);
	OCIExtProcRaiseExcpWithMsg(ctx, ORACLE_USER_ERR, str, 0);
}

#if 0
/* NEEDS REAL ERROR MESSAGES */
int simple_text_query(OCIExtProcContext *ctx, char *sql, char *res)
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
#endif

PerlInterpreter *pl_startup(void)
{
	PerlInterpreter *p;
	char *args[] = { "", BOOTSTRAP_FILE };

	if((p = perl_alloc()) == NULL) {
		return(NULL);
	}
	PL_perl_destruct_level = 0;
	perl_construct(p);
	if (!perl_parse(p, xs_init, 2, args, NULL)) {
		if (perl_run(p)) {
			return(p);
		}
	}
	return(NULL);
}

void pl_shutdown(PerlInterpreter *p)
{
	perl_destruct(p);
	perl_free(p);
}

static char *call_perl_sub(OCIExtProcContext *ctx, char *sub, char **args)
{
	STRLEN len;
	int nret;
	char *tmp, *retval, **p;
	SV *sv;
	dSP;

	/* push arguments onto stack */
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	p = args;
	while (*p) {
		XPUSHs(sv_2mortal(newSVpv(*p++,0)));
	}
	PUTBACK;

	/* run subroutine */
	nret = call_pv(sub, G_SCALAR|G_EVAL);
	SPAGAIN;

	/* grab return value, detecting errors along the way */
	if (SvTRUE(ERRSV) || nret != 1) {
		ora_exception(ctx, SvPV(ERRSV, PL_na));
		POPs;
		retval = NULL;
	}
	else {
		sv = POPs;
		tmp = SvPV(sv,len);
		/* use oracle's memory allocation in case we're unloaded */
		retval = OCIExtProcAllocCallMemory(ctx, len+1);
		Copy(tmp, retval, len, char);
		retval[len] = '\0';
	}

	/* clean up stack and return */
	PUTBACK;
	FREETMPS;
	LEAVE;
	return(retval);
}

char *ora_perl_sub(OCIExtProcContext *ctx, OCIInd *ret_ind, char *sub, ...)
{
	int status, n = 0;
	va_list ap;
	short ind;
	char *args[MAXARGS], *retval, user[1024];

	/* set OCI context for ExtProc module */
	this_ctx = ctx;

	/* grab arguments, NULL terminated */
	va_start(ap, sub);

	while (n < MAXARGS) {
		args[n] = va_arg(ap, char*);
		ind = va_arg(ap, int);
		if (ind == OCI_IND_NULL) {
			args[n] = NULL;
			break;
		}
		n++;
	}
	va_end(ap);

	/* check for flush request */
	if (!strncmp(sub, "_flush", 6) && perl) {
		pl_shutdown(perl);
		perl = NULL;
		*ret_ind = OCI_IND_NULL;
		return("\0");
	}

	/* check for version request */
	if (!strncmp(sub, "_version", 8)) {
		*ret_ind = OCI_IND_NOTNULL;
		return(EXTPROC_PERL_VERSION);
	}

	/* start perl interpreter if necessary */
	if (!perl) {
		perl = pl_startup();
		if (!perl) {
			*ret_ind = OCI_IND_NULL;
			ora_exception(ctx, "pl_startup failed -- check bootstrap file with 'perl -cw'");
			return("\0");
		}
	}

	/* verify that the subroutine is valid (autoloading not supported) */
	if (!get_sv(sub, FALSE)) {
		*ret_ind = OCI_IND_NULL;
		ora_exception(ctx, "invalid subroutine");
		return("\0");
	}

	/* run subroutine */
	retval = call_perl_sub(ctx, sub, args);
	*ret_ind = retval ? OCI_IND_NOTNULL : OCI_IND_NULL;

	return(retval);
}
