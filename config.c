/* $Id: config.c,v 1.11 2004/01/09 21:14:16 jeff Exp $ */

#ifdef __cplusplus
extern "C" {
#endif
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <oci.h>
#include <EXTERN.h>
#include <perl.h>
#include "extproc_perl.h"
#ifdef __cplusplus
}
#endif

#define YESORNO(x) (!strncasecmp(x, "yes", 3) ? 1 : 0)

int read_config(EP_CONTEXT *c, char *fn)
{
	FILE *fp;
	char line[1024], err[256], key[1024], val[1024], *p;
	int len, i, n = 0;

	if (!(fp = fopen(fn, "r"))) {
		return 0;
	}

	while(fgets(line, 1024, fp)) {
		n++;
		/* ignore comments and blank lines */
		if (line[0] == '#' || line[0] == '\n') {
			continue;
		}

		/* parse away */
		if ((p = strpbrk(line, " \t"))) {
			len = p-line;
			strncpy(key, line, len);
			key[len] = '\0';
			strncpy(val, p+1, 1024-len-1);
			/* get rid of newline */
			if ((p = strchr(val, '\n'))) {
				*p = '\0';
			}
		}
		else {
			snprintf(err, 255, "Bad configuration line %d\n", n);
			ora_exception(c, err);
			return(0);
		}

		if (!strcmp(key, "code_table")) {
			strncpy(c->code_table, val, 255);
			continue;
		}
		if (!strcmp(key, "bootstrap_file")) {
			strncpy(c->bootstrap_file, val, MAXPATHLEN-1);
			continue;
		}
		if (!strcmp(key, "debug_directory")) {
			strncpy(c->debug_dir, val, MAXPATHLEN-1);
			continue;
		}
		if (!strcmp(key, "inc_path")) {
			strncpy(c->inc_path, val, 4095);
			continue;
		}
		if (!strcmp(key, "trusted_code_directory")) {
			strncpy(c->trusted_dir, val, MAXPATHLEN-1);
			continue;
		}
		if (!strcmp(key, "enable_session_namespace")) {
			c->use_namespace = YESORNO(val);
			continue;
		}
		if (!strcmp(key, "enable_tainting")) {
			c->tainting = YESORNO(val);
			continue;
		}
		if (!strcmp(key, "enable_opcode_security")) {
			c->opcode_security = YESORNO(val);
			continue;
		}
		if (!strcmp(key, "enable_package_subs")) {
			c->package_subs = YESORNO(val);
			continue;
		}
		if (!strcmp(key, "max_code_size")) {
			i = atoi(val);
			if (i < 1 || i > 4000) {
				snprintf(err, 255, "Illegal value for max_code_size: '%s'\n", val);
				ora_exception(c, err);
				return 0;
			}
			c->max_code_size = i;
			continue;
		}
		if (!strcmp(key, "max_sub_args")) {
			i = atoi(val);
			if (i < 0 || i > 128) {
				snprintf(err, 255, "Illegal value for max_sub_args: '%s'\n", val);
				ora_exception(c, err);
				return 0;
			}
			c->max_sub_args = i;
			continue;
		}
	}

	fclose(fp);

	return 1;
}
