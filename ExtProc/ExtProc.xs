/*
 * Oracle Perl Procedure Library
 *
 * Copyright (c) 2001 Jeff Horwitz (jeff@smashing.org).  All rights reserved.
 * This package is free software; you can redistribute it and/or modify it
 * under the same terms as Perl itself.
 */

/* $Id: ExtProc.xs,v 1.4 2001/08/31 15:00:15 jhorwitz Exp $ */

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
typedef struct OCIExtProcContext *ExtProc__OCIExtProcContext;

MODULE = ExtProc		PACKAGE = ExtProc		

void
exception(msg)
	char *msg;

	CODE:
	ora_exception(this_ctx, msg);

ExtProc::OCIExtProcContext
context()
	CODE:
	RETVAL = this_ctx;

	OUTPUT:
	RETVAL
