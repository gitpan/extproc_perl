/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001, 2002, 2003 Jeff Horwitz (jeff@smashing.org).
 * All rights reserved.
 */

/* $Id: extproc_perl.h,v 1.17 2003/05/22 16:37:51 jeff Exp $ */

#ifndef EXTPROC_PERL_H
#define EXTPROC_PERL_H

#define	MAXARGS			32
#define	ORACLE_USER_ERR		20100
#define MAX_SIMPLE_QUERY_RESULT	8192
#define MAX_SIMPLE_QUERY_SQL	256
#define MAX_CODE_SIZE		8192 /* <= MAX_SIMPLE_QUERY_RESULT */

#ifdef EP_DEBUGGING
#define EP_DEBUG(msg) if (ep_debugging) { ep_debug("%s", msg); }
#define EP_DEBUGF(fmt, ...) if (ep_debugging) { ep_debug(fmt, __VA_ARGS__); }
#else
#define EP_DEBUG(msg) 1;
#define EP_DEBUGF(fmt, ...) 1;
#endif /* EP_DEBUGGING */

struct ocictx {
	OCIExtProcContext *ctx;	/* For OCI ExtProc Context */
	OCIEnv *envhp;		/* For OCI Environment Handle */
	OCISvcCtx *svchp;	/* For OCI Service Handle */
	OCIError *errhp;	/* For OCI Error Handle  */
	OCIStmt *stmtp;		/* For OCI Statement Handle */
	OCIStmt *stm1p;		/* For OCI Statement Handle */
	OCIBind *bnd1p;		/* For OCI Bind Handle */
	OCIBind *bnd2p;		/* For OCI Bind Handle */
	OCIBind *bnd3p;		/* For OCI Bind Handle */
	OCIDefine *dfn1p;	/* For OCI Define Handle */
	OCIDefine *dfn2p;	/* For OCI Define Handle */
	OCIDefine *dfn3p;	/* For OCI Define Handle */
};
typedef struct ocictx ocictx;

void ora_exception(OCIExtProcContext *, char *);

int simple_query(OCIExtProcContext *, char *, char *, int);

#endif /* EXTPROC_PERL_H */
