/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001, 2002, 2003 Jeff Horwitz (jeff@smashing.org).
 * All rights reserved.
 */

/* $Id: extproc_perl.c,v 1.38 2003/06/18 17:02:07 jeff Exp $ */

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
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

#define EXTPROC_PERL_VERSION	"1.01"

#define PERL_NO_GET_CONTEXT

static PerlInterpreter *perl;
static char code_table[256];
ocictx this_ctx; /* for ExtProc module & DBI */
int _connected; /* for collaboration between extproc_perl & DBI */

EXTERN_C void xs_init();

#ifdef EP_DEBUGGING
static int ep_debugging; /* debug logging flag */
static FILE *epfp; /* debug log file structure */

char *ep_debug_enable(OCIExtProcContext *ctx)
{
	char *fname;
	pid_t pid;

	if (ep_debugging) return;

	ep_debugging = 1;

	/* use oracle's memory allocation in case we're unloaded */
	fname = OCIExtProcAllocCallMemory(ctx, MAXPATHLEN+1);
		
	/* open log file */
	pid = getpid();
	snprintf(fname, MAXPATHLEN, "/tmp/ep_debug.%d", pid);
	if (!(epfp = fopen(fname, "a+"))) {
		fprintf(stderr, "extproc_perl: open failed for debug log %s",
			fname);
		return(NULL);
	}

	/* redirect stderr */
	dup2(fileno(epfp), fileno(stderr));

	return(fname);
}

void ep_debug_disable(void)
{
	if (!ep_debugging) return;

	ep_debugging = 0;

	/* close log file & stderr */
	fclose(epfp);
	fclose(stderr);
}

void ep_debug(char *fmt, ...)
{
	va_list ap;
	char args[32], *ts;
	int n = 0;
	time_t t;

	va_start(ap, fmt);
	t = time(NULL);
	ts = ctime(&t);
	ts[strlen(ts)-1] = '\0';
	fprintf(epfp, "%s ", ts);
	vfprintf(epfp, fmt, ap);
	fprintf(epfp, "\n");
	fflush(epfp);
}
#endif /* EP_DEBUGGING */

void ora_exception(OCIExtProcContext *ctx, char *msg)
{
	char str[1024];

	EP_DEBUGF("IN ora_exception(%p, \"%s\")", ctx, msg);
	snprintf(str, 1023, "PERL EXTPROC ERROR: %s\n", msg);
	OCIExtProcRaiseExcpWithMsg(ctx, ORACLE_USER_ERR, str, 0);
}

PerlInterpreter *pl_startup(void)
{
	PerlInterpreter *p;
	int argc;
	char *argv[4];
	struct stat st;
	SV *sv;

	dTHX;

#ifdef EP_DEBUGGING
	/* initialize ep_debug to a sane value */
	if (ep_debugging != 1) {
		ep_debugging = 0;
	}
#endif /* EP_DEBUGGING */
	EP_DEBUG("IN pl_startup()");

	/* create interpreter */
	if((p = perl_alloc()) == NULL) {
		EP_DEBUG("perl_alloc() failed!");
		return(NULL);
	}
	PL_perl_destruct_level = 0;
	perl_construct(p);
	EP_DEBUGF("-- Perl interpreter created: p=%p", p);

	/* parse bootstrap file if it exists */
	if (!stat(BOOTSTRAP_FILE, &st)) {
		EP_DEBUGF("-- Using bootstrap file '%s'", BOOTSTRAP_FILE);
		argv[0] = "";
#ifdef EP_TAINTING
		argv[1] = "-T";
		argv[2] = BOOTSTRAP_FILE;
		argc = 3;
#else
		argv[1] = BOOTSTRAP_FILE;
		argc = 2;
#endif /* EP_TAINTING */
	}
	else {
		EP_DEBUG("-- No bootstrap file found.  Move along.");
		argv[0] = "";
#ifdef EP_TAINTING
		argv[1] = "-T";
		argv[2] = "-e";
		argv[3] = "0";
		argc = 4;
#else
		argv[1] = "-e";
		argv[2] = "0";
		argc = 3;
#endif /* EP_TAINTING */
	}

	if (!perl_parse(p, xs_init, argc, argv, NULL)) {
		if (!perl_run(p)) {
			load_module(aTHX_ PERL_LOADMOD_NOIMPORT,(SV*)newSVpv("ExtProc",0),Nullsv);
			EP_DEBUG("-- Bootstrapping successful!");
			return(p);
		}
	}
	return(NULL);
}

void pl_shutdown(PerlInterpreter *p)
{
	EP_DEBUGF("IN pl_shutdown(%p)", p);
	perl_destruct(p);
	perl_free(p);
}

static char *get_code(OCIExtProcContext *ctx, char *table, char *buf)
{
	OCILobLocator *lobl;
	char sql[MAX_SIMPLE_QUERY_SQL];
	int buflen = MAX_SIMPLE_QUERY_RESULT;

	EP_DEBUGF("IN get_code(%p, \"%s\", %p)", ctx, table, buf);
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

	dTHX;

	dSP;

	EP_DEBUGF("IN call_perl_sub(%p, \"%s\", ...)", ctx, sub);

	/* push arguments onto stack */
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	p = args;
	while (*p) {
		sv = sv_2mortal(newSVpv(*p++,0));
#ifdef EP_TAINTING
		SvTAINTED_on(sv);
#endif EP_TAINTING
		XPUSHs(sv);
	}
	PUTBACK;

	/* run subroutine */
	EP_DEBUG("-- about to call call_pv()");
	nret = call_pv(sub, G_SCALAR|G_EVAL);
	EP_DEBUGF("-- call_pv() returned %d", nret);
	SPAGAIN;

	/* grab return value, detecting errors along the way */
	if (SvTRUE(ERRSV) || nret != 1) {
		EP_DEBUGF("-- ERRSV is defined: %s", SvPV(ERRSV, PL_na));
		ora_exception(ctx, SvPV(ERRSV, PL_na));
		POPs;
		retval = NULL;
	}
	else {
		EP_DEBUG("-- No errors detected");
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

/* entry point from oracle function */
char *ora_perl_func(OCIExtProcContext *ctx, OCIInd *ret_ind, char *sub, ...)
{
	int status, n = 0;
	va_list ap;
	short ind;
	char *args[MAXARGS], *retval, code[MAX_CODE_SIZE], *errbuf;
	SV *evalsv;

	dTHX;

	EP_DEBUGF("IN ora_perl_func(%p, %p, \"%s\", ...)", ctx, ret_ind, sub);

	/* set OCI context for ExtProc module */
	this_ctx.ctx = ctx;

	/* new transaction, new extproc "connection" */
	_connected = 0;

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

	EP_DEBUGF("-- found %d argument(s)", n);

#ifdef EP_DEBUGGING
	/* check for debug request */
	if (!strncmp(sub, "_enable_debug", 13)) {
		if ((retval = ep_debug_enable(ctx))) {
			*ret_ind = OCI_IND_NOTNULL;
		}
		else {
			*ret_ind = OCI_IND_NULL;
		}
		return(retval);
	}

	if (!strncmp(sub, "_disable_debug", 14)) {
		ep_debug_disable();
		*ret_ind = OCI_IND_NULL;
		return("\0");
	}
#endif /* DEBUGGING */

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

	/* check for request to load code from the database */
	if (!strncmp(sub, "_preload", 10)) {
		get_code(ctx, code_table, code);
		TAINT_NOT;
		eval_pv(code, TRUE);
		TAINT;
		*ret_ind = OCI_IND_NULL;
		return("\0");
	}

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

	/* check for errno request */
	if (!strncmp(sub, "_errno", 6)) {
		if (errno) {
			errbuf = strerror(errno);
			*ret_ind = OCI_IND_NOTNULL;
			return(errbuf);
		}
		else {
			*ret_ind = OCI_IND_NULL;
			return("\0");
		}
	}

	/* check for eval request */
	if (!strncmp(sub, "_eval", 6)) {
		evalsv = eval_pv(args[0], FALSE);
		if (SvTRUE(ERRSV)) {
			ora_exception(ctx, SvPV(ERRSV, PL_na));
		}
		*ret_ind = SvOK(evalsv) ? OCI_IND_NOTNULL : OCI_IND_NULL;
		retval = SvPV(sv_2mortal(evalsv), PL_na);
		return(retval);
	}

	/*
	 * verify that the subroutine is valid (autoloading not supported)
	 * try loading code from database if it isn't initially valid.
	 */
	if (!get_cv(sub, FALSE)) {
		EP_DEBUG("-- CV does not exist, trying database...");
		/* load code -- fail silently if no code is available */
		get_code(ctx, code_table, code);

		/* parse code */
		EP_DEBUG("-- parsing code from database...");
		TAINT_NOT;
		eval_pv(code, TRUE);
		TAINT;
		EP_DEBUG("-- parsing successful");

		/* try again */
		if (!get_cv(sub, FALSE)) {
			EP_DEBUG("-- CV STILL doesn't exist!");
			*ret_ind = OCI_IND_NULL;
			ora_exception(ctx, "invalid subroutine");
			return("\0");
		}
		EP_DEBUG("-- CV exists!");
	}

	EP_DEBUG("-- CV is cached");

	/* run subroutine */
	retval = call_perl_sub(ctx, sub, args);
	*ret_ind = retval ? OCI_IND_NOTNULL : OCI_IND_NULL;

	return(retval);
}

/* entry point from oracle procedure */
void ora_perl_proc(OCIExtProcContext *ctx, char *sub, ...)
{
	int status, n = 0;
	va_list ap;
	short ind;
	char *args[MAXARGS], code[MAX_CODE_SIZE];

	dTHX;

	EP_DEBUGF("IN ora_perl_proc(%p, \"%s\", ...)", ctx, sub);

	/* set OCI context for ExtProc module */
	this_ctx.ctx = ctx;

	/* new transaction, new extproc "connection" */
	_connected = 0;

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

	EP_DEBUGF("-- found %d argument(s)", n);

#ifdef EP_DEBUGGING
	/* check for debug request */
	if (!strncmp(sub, "_enable_debug", 13)) {
		ep_debug_enable(ctx);
		return;
	}

	if (!strncmp(sub, "_disable_debug", 14)) {
		ep_debug_disable();
		return;
	}
#endif /* EP_DEBUGGING */

	/* check for flush request */
	if (!strncmp(sub, "_flush", 6)) {
		/* only destroy the interpreter if it exists */
		if (perl) {
			pl_shutdown(perl);
			perl = NULL;
		}
		return;
	}

	/* start perl interpreter if necessary */
	if (!perl) {
		perl = pl_startup();
		if (!perl) {
			ora_exception(ctx, "pl_startup failed -- check bootstrap file with 'perl -cw'");
			return;
		}
		/* set code table */
		strncpy(code_table, CODE_TABLE, 255);
	}

	/* the following special subs must be run AFTER the perl interpreter */
	/* has been initialized */

	/* check for request to load code from the database */
	if (!strncmp(sub, "_preload", 10)) {
		get_code(ctx, code_table, code);
		TAINT_NOT;
		eval_pv(code, TRUE);
		TAINT;
		return;
	}

	/* check for code table change */
	if (!strncmp(sub, "_codetable", 10)) {
		if (args[0]) {
			strncpy(code_table, args[0], 255);
		}
		else {
			ora_exception(ctx, "can't return codetable from a procedure'");
			return;
		}
	}

	/* check for eval request */
	if (!strncmp(sub, "_eval", 6)) {
		eval_pv(args[0], FALSE);
		if (SvTRUE(ERRSV)) {
			ora_exception(ctx, SvPV(ERRSV, PL_na));
		}
		return;
	}

	/*
	 * verify that the subroutine is valid (autoloading not supported)
	 * try loading code from database if it isn't initially valid.
	 */
	if (!get_cv(sub, FALSE)) {
		/* load code -- fail silently if no code is available */
		get_code(ctx, code_table, code);

		/* parse code */
		TAINT_NOT;
		eval_pv(code, TRUE);
		TAINT;

		/* try again */
		if (!get_cv(sub, FALSE)) {
			ora_exception(ctx, "invalid subroutine");
			return;
		}
	}

	/* run subroutine */
	call_perl_sub(ctx, sub, args);
}
