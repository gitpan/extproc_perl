/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001, 2002 Jeff Horwitz (jeff@smashing.org).
 * All rights reserved.
 *
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: extproc_perl.c,v 1.17 2002/11/22 19:26:40 jhorwitz Exp $ */

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <time.h>
#include <oci.h>
#include <EXTERN.h>
#include <perl.h>
#include "extproc_perl.h"
#ifdef __cplusplus
}
#endif

#define EXTPROC_PERL_VERSION	"0.94"

static PerlInterpreter *perl;
static char code_table[256];
OCIExtProcContext *this_ctx; /* for ExtProc module */

void ora_exception(OCIExtProcContext *ctx, char *msg)
{
	char str[1024];

	snprintf(str, 1023, "PERL EXTPROC ERROR: %s\n", msg);
	OCIExtProcRaiseExcpWithMsg(ctx, ORACLE_USER_ERR, str, 0);
}

PerlInterpreter *pl_startup(void)
{
	PerlInterpreter *p;
	int argc;
	char *argv[3];
	struct stat st;

	/* create interpreter */
	if((p = perl_alloc()) == NULL) {
		return(NULL);
	}
	PL_perl_destruct_level = 0;
	perl_construct(p);

	/* parse bootstrap file if it exists */
	if (!stat(BOOTSTRAP_FILE, &st)) {
		argv[0] = "";
		argv[1] = BOOTSTRAP_FILE;
		argc = 2;
	}
	else {
		argv[0] = "";
		argv[1] = "-e";
		argv[2] = "0";
		argc = 3;
	}

	if (!perl_parse(p, xs_init, argc, argv, NULL)) {
		if (!perl_run(p)) {
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

static char *get_code(OCIExtProcContext *ctx, char *table, char *buf)
{
	OCILobLocator *lobl;
	char sql[MAX_SIMPLE_QUERY_SQL];
	int buflen = MAX_SIMPLE_QUERY_RESULT;

	snprintf(sql, MAX_SIMPLE_QUERY_SQL - 18, "select code from %s", table);
	simple_lob_query(ctx, sql, lobl, buf, &buflen, 0);
	return(buf);
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

/* entry point from oracle external procedure process */
char *ora_perl_sub(OCIExtProcContext *ctx, OCIInd *ret_ind, char *sub, ...)
{
	int status, n = 0;
	va_list ap;
	short ind;
	char *args[MAXARGS], *retval, user[1024], code[MAX_CODE_SIZE];

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
	if (!strncmp(sub, "_flush", 6)) {
		/* only destroy the interpreter if it exists */
		if (perl) {
			pl_shutdown(perl);
			perl = NULL;
		}
		*ret_ind = OCI_IND_NULL;
		return("\0");
	}

	/* check for version request */
	if (!strncmp(sub, "_version", 8)) {
		*ret_ind = OCI_IND_NOTNULL;
		return(EXTPROC_PERL_VERSION);
	}

	/* check for module list request */
	if (!strncmp(sub, "_modules", 8)) {
		*ret_ind = OCI_IND_NOTNULL;
		return(STATIC_MODULES);
	}

	/* start perl interpreter if necessary */
	if (!perl) {
		perl = pl_startup();
		if (!perl) {
			*ret_ind = OCI_IND_NULL;
			ora_exception(ctx, "pl_startup failed -- check bootstrap file with 'perl -cw'");
			return("\0");
		}
		/* set code table */
		strncpy(code_table, CODE_TABLE, 255);
	}

	/* the following special subs must be run AFTER the perl interpreter */
	/* has been initialized */

	/* check for code table change */
	if (!strncmp(sub, "_codetable", 10)) {
		if (args[0]) {
			strncpy(code_table, args[0], 255);
		}
		*ret_ind = OCI_IND_NOTNULL;
		return(code_table);
	}

	/* check for error message request */
	if (!strncmp(sub, "_error", 6)) {
		if (SvTRUE(ERRSV)) {
			*ret_ind = OCI_IND_NOTNULL;
			return(SvPV(ERRSV,PL_na));
		}
		else {
			*ret_ind = OCI_IND_NULL;
			return("\0");
		}
	}

	/* check for easter egg */
	if (!strncmp(sub, "_easteregg", 10)) {
		*ret_ind = OCI_IND_NOTNULL;
		return("Sorry, no easter eggs here.  They're a waste of resources. :-D");
	}

	/*
	 * verify that the subroutine is valid (autoloading not supported)
	 * try loading code from database if it isn't initially valid.
	 */
	if (!get_cv(sub, FALSE)) {
		/* load code -- fail silently if no code is available */
		get_code(ctx, code_table, code);

		/* parse code */
		eval_pv(code, TRUE);

		/* try again */
		if (!get_cv(sub, FALSE)) {
			*ret_ind = OCI_IND_NULL;
			ora_exception(ctx, "invalid subroutine");
			return("\0");
		}
	}

	/* run subroutine */
	retval = call_perl_sub(ctx, sub, args);
	*ret_ind = retval ? OCI_IND_NOTNULL : OCI_IND_NULL;

	return(retval);
}
