/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001 Jeff Horwitz (jeff@smashing.org).  All rights reserved.
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: extproc_perl.h,v 1.3 2001/08/15 14:47:57 jhorwitz Exp $ */

#ifndef ORAPERLSUB_H
#define ORAPERLSUB_H

#define MY_SUCCESS      0
#define MY_FAILED       1
#define MAXARGS         32
#define ORACLE_USER_ERR	20100

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

#endif /* ORAPERLSUB_H */
