/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001, 2002 Jeff Horwitz (jeff@smashing.org).
 * All rights reserved.
 *
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: extproc_perl.h,v 1.10 2002/11/18 01:22:33 jhorwitz Exp $ */

#ifndef EXTPROC_PERL_H
#define EXTPROC_PERL_H

#define	MAXARGS			32
#define	ORACLE_USER_ERR		20100
#define MAX_SIMPLE_QUERY_RESULT	8192
#define MAX_SIMPLE_QUERY_SQL	256
#define MAX_CODE_SIZE		8192 /* <= MAX_SIMPLE_QUERY_RESULT */

struct ocictx {
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

void xs_init(void);

void ora_exception(OCIExtProcContext *, char *);

int simple_query(OCIExtProcContext *, char *, char *, int);

#endif /* EXTPROC_PERL_H */
