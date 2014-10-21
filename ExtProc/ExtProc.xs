/* $Id: ExtProc.xs,v 1.9 2004/01/10 02:02:55 jeff Exp $ */

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
typedef OCIDate *ExtProc__DataType__OCIDate;

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

MODULE = ExtProc	PACKAGE = ExtProc::DataType::OCIDate	PREFIX = EPDT_OCIDate_
PROTOTYPES: disable

void
EPDT_OCIDate_getdate(d)
	ExtProc::DataType::OCIDate d

	PREINIT:
	int year;
	int month;
	int day;

	PPCODE:
	OCIDateGetDate(d, &year, &month, &day);
	XPUSHs(newSViv(year));
	XPUSHs(newSViv(month));
	XPUSHs(newSViv(day));

void
EPDT_OCIDate_setdate(d, year, month, day)
	ExtProc::DataType::OCIDate d
	int year
	int month
	int day

	CODE:
	OCIDateSetDate(d, year, month, day);

void
EPDT_OCIDate_gettime(d)
	ExtProc::DataType::OCIDate d

	PREINIT:
	int hour;
	int min;
	int sec;

	PPCODE:
	OCIDateGetTime(d, &hour, &min, &sec);
	XPUSHs(newSViv(hour));
	XPUSHs(newSViv(min));
	XPUSHs(newSViv(sec));

void
EPDT_OCIDate_settime(d, hour, min, sec)
	ExtProc::DataType::OCIDate d
	int hour
	int min
	int sec

	CODE:
	OCIDateSetTime(d, hour, min, sec);

SV *
EPDT_OCIDate_to_char(d, fmt)
	ExtProc::DataType::OCIDate d
	char *fmt

	PREINIT:
	char *string;

	CODE:
	string = ocidate_to_string(my_contextp, d, fmt);
	RETVAL = sv_2mortal(newSVpv(string, 0));

	OUTPUT:
	RETVAL
