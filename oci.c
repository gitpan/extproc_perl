/* $Id: oci.c,v 1.5 2003/11/13 16:46:08 jeff Exp $ */

#include <oci.h>
#include <EXTERN.h>
#include <perl.h>
#include "extproc_perl.h"

/* int ep_OCIExtProcGetEnv(EP_CONTEXT *c)
 * wrapper around oracle's OCIExtProcGetEnv
 * we can't call getenv twice in the same transaction, so we need to save
 * our handles for later use by DBI
 */
int ep_OCIExtProcGetEnv(EP_CONTEXT *c)
{
	int err;

	dTHX;

	if (!c->connected) {
		err = OCIExtProcGetEnv(c->oci_context.ctx,
			&c->oci_context.envhp, &c->oci_context.svchp,
			&c->oci_context.errhp);
		if (err == OCI_SUCCESS || err == OCI_SUCCESS_WITH_INFO) {
			c->connected = 1;
		}
	}
	else {
		/* return success if we've already connected */
		err = OCI_SUCCESS;
	}
	return(err);
}

int fetch_code(EP_CONTEXT *c, EP_CODE *code, char *name)
{
	char sql[255], *buf;
	ocictx *this_ctxp = &(c->oci_context);
	OCIDefine *def1 = (OCIDefine *) 0;
	OCIDefine *def2 = (OCIDefine *) 0;
	OCIBind *bind1 = (OCIBind *) 0;
	int err;
	
	EP_DEBUGF(c, "IN fetch_code(%p, %p, \"%s\")", c, code, name);

	err = ep_OCIExtProcGetEnv(c);

	/* allocate code buffer */
	buf = OCIExtProcAllocCallMemory(c->oci_context.ctx, c->max_code_size);

	snprintf(sql, 255, "select code, language from %s where name = :name", c->code_table);

	if (err) {
		ora_exception(c,"getenv");
		return(err);
	}

	err = OCIHandleAlloc(this_ctxp->envhp,
		(dvoid **)&this_ctxp->stmtp,
		OCI_HTYPE_STMT,
		0,
		0);

	if (err) {
		ora_exception(c,"handlealloc");
		return(err);
	}

	err = OCIStmtPrepare(this_ctxp->stmtp,
		this_ctxp->errhp,
		(text *) sql,
		strlen(sql),
		OCI_NTV_SYNTAX,
		OCI_DEFAULT);

	if (err) {
		ora_exception(c,"prepare");
		return(err);
	}

	err = OCIDefineByPos(this_ctxp->stmtp,
		&def1,
		this_ctxp->errhp,
		1,
		buf,
		4000,
		SQLT_STR,
		(dvoid *) 0,
		(dvoid *) 0,
		(dvoid *) 0,
		OCI_DEFAULT);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		ora_exception(c,"define1");
		return(err);
	}

	err = OCIDefineByPos(this_ctxp->stmtp,
		&def2,
		this_ctxp->errhp,
		2,
		code->language,
		16,
		SQLT_STR,
		(dvoid *) 0,
		(dvoid *) 0,
		(dvoid *) 0,
		OCI_DEFAULT);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		ora_exception(c,"define2");
		return(err);
	}

	err = OCIBindByPos(this_ctxp->stmtp,
		&bind1,
		this_ctxp->errhp,
		1,
		name,
		strlen(name),
		SQLT_CHR,
		(dvoid *) 0,
		(ub2 *) 0,
		(ub2 *) 0,
		(ub4) 0,
		(ub4 *) 0,
		OCI_DEFAULT);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		ora_exception(c,"bind");
		return(err);
	}

	err = OCIStmtExecute(this_ctxp->svchp,
		this_ctxp->stmtp,
		this_ctxp->errhp,
		1,
		0,
		NULL,
		NULL,
		OCI_DEFAULT);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		/* don't throw an exception for a valid empty result */
		if (err != OCI_NO_DATA) {
			ora_exception(c,"exec");
		}
		return(err);
	}

	err = OCIHandleFree(this_ctxp->stmtp, OCI_HTYPE_STMT);
	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		ora_exception(c,"OCIHandleFree");
		return(err);
	}

	code->code = buf;

	return(OCI_SUCCESS);
}
int get_sessionid(EP_CONTEXT *c, int *sessionid)
{
	char *sql;
	ocictx *this_ctxp = &(c->oci_context);
	OCIDefine *def1 = (OCIDefine *) 0;
	int err;
	
	EP_DEBUGF(c, "IN get_sessionid(%p)", c);

	err = ep_OCIExtProcGetEnv(c);

	if (err) {
		ora_exception(c,"getenv");
		return(err);
	}

	err = OCIHandleAlloc(this_ctxp->envhp,
		(dvoid **)&this_ctxp->stmtp,
		OCI_HTYPE_STMT,
		0,
		0);

	if (err) {
		ora_exception(c,"handlealloc");
		return(err);
	}

	sql = "select USERENV('sessionid') from dual";
	err = OCIStmtPrepare(this_ctxp->stmtp,
		this_ctxp->errhp,
		(text *) sql,
		strlen(sql),
		OCI_NTV_SYNTAX,
		OCI_DEFAULT);

	if (err) {
		ora_exception(c,"prepare");
		return(err);
	}

	err = OCIDefineByPos(this_ctxp->stmtp,
		&def1,
		this_ctxp->errhp,
		1,
		sessionid,
		sizeof(int),
		SQLT_INT,
		(dvoid *) 0,
		(dvoid *) 0,
		(dvoid *) 0,
		OCI_DEFAULT);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		ora_exception(c,"define1");
		return(err);
	}

	err = OCIStmtExecute(this_ctxp->svchp,
		this_ctxp->stmtp,
		this_ctxp->errhp,
		1,
		0,
		NULL,
		NULL,
		OCI_DEFAULT);

	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		ora_exception(c,"exec");
		return(err);
	}

	err = OCIHandleFree(this_ctxp->stmtp, OCI_HTYPE_STMT);
	if ((err != OCI_SUCCESS) && (err != OCI_SUCCESS_WITH_INFO)) {
		ora_exception(c,"OCIHandleFree");
		return(err);
	}

	return(OCI_SUCCESS);
}
