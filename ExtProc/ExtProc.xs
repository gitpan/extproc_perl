/* $Id: ExtProc.xs,v 1.8 2003/11/12 00:00:25 jeff Exp $ */

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

extern EP_CONTEXT my_context;
EP_CONTEXT *my_contextp = &my_context;

typedef struct OCIExtProcContext *ExtProc__OCIExtProcContext;
typedef struct OCIEnv *ExtProc__OCIEnvHandle;
typedef struct OCISvcCtx *ExtProc__OCISvcHandle;
typedef struct OCIError *ExtProc__OCIErrHandle;

MODULE = ExtProc		PACKAGE = ExtProc		
PROTOTYPES: disable

void
ora_exception(msg)
	char *msg;

	CODE:
	ora_exception(my_contextp, msg);

ExtProc::OCIExtProcContext
context()
	CODE:
	RETVAL = my_contextp->oci_context.ctx;

	OUTPUT:
	RETVAL

void
_connected_on()
	CODE:
	my_contextp->connected = 1;

void
_connected_off()
	CODE:
	my_contextp->connected = 0;

int
_is_connected()
	CODE:
	RETVAL = my_contextp->connected;

	OUTPUT:
	RETVAL

ExtProc::OCIEnvHandle
_envhp()
	CODE:
	RETVAL = my_contextp->oci_context.envhp;

	OUTPUT:
	RETVAL

ExtProc::OCISvcHandle
_svchp()
	CODE:
	RETVAL = my_contextp->oci_context.svchp;

	OUTPUT:
	RETVAL

ExtProc::OCIErrHandle
_errhp()
	CODE:
	RETVAL = my_contextp->oci_context.errhp;

	OUTPUT:
	RETVAL

void
ep_debug(msg)
	char *msg;

	CODE:
	if (my_contextp->debug) {
		ep_debug(my_contextp, msg);
	}

int
is_function()
	CODE:
	RETVAL = (my_contextp->subtype == EP_SUBTYPE_FUNCTION) ? 1 : 0;

	OUTPUT:
	RETVAL

int
is_procedure()
	CODE:
	RETVAL = (my_contextp->subtype == EP_SUBTYPE_PROCEDURE) ? 1 : 0;

	OUTPUT:
	RETVAL

SV *
config(name)
	char *name;

	PPCODE:
	if (strEQ(name, "code_table")) {
		XPUSHs(newSVpv(my_contextp->code_table, 0));
	}
	else if (strEQ(name, "trusted_code_directory")) {
		XPUSHs(newSVpv(my_contextp->trusted_dir, 0));
	}
	else {
		ora_exception(my_contextp, "unknown configuration directive");
		XSRETURN_UNDEF;
	}
