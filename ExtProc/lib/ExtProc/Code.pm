# $Id: Code.pm,v 1.44 2004/09/16 20:17:42 jeff Exp $

package ExtProc::Code;

use 5.6.1;
use strict;
use warnings;
use AutoLoader 'AUTOLOAD';

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(
	&create_wrapper
	&import_code
	&drop_code
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(
);
our $VERSION = '2.01';

use ExtProc qw(ep_debug put_line);
use File::Spec;
use DBI;

use vars qw(%typemap $c_prefix);

# for converting from *supported* PL/SQL datatypes to C datatypes
# should explore integrating this with OTT somehow
%typemap = (
	'PLS_INTEGER' => {
		'IN'		=> 'int',
		'OUT'		=> 'int *',
		'IN OUT'	=> 'int *',
		'RETURN'	=> 'int',
		'PARAMTYPE'	=> 'int',
		'NULLABLE'	=> 1,
		'VARLENGTH'	=> 0
	},
	'REAL' => {
		'IN'		=> 'float',
		'OUT'		=> 'float *',
		'IN OUT'	=> 'float *',
		'RETURN'	=> 'float',
		'PARAMTYPE'	=> 'float',
		'NULLABLE'	=> 1,
		'VARLENGTH'	=> 0
	},
	'VARCHAR2' => {
		'IN'		=> 'char *',
		'OUT'		=> 'char *',
		'IN OUT'	=> 'char *',
		'RETURN'	=> 'char *',
		'PARAMTYPE'	=> 'string',
		'NULLABLE'	=> 1,
		'VARLENGTH'	=> 1
	},
	'DATE' => {
		'IN'		=> 'OCIDate *',
		'OUT'		=> 'OCIDate *',
		'IN OUT'	=> 'OCIDate *',
		'RETURN'	=> 'OCIDate *',
		'PARAMTYPE'	=> 'OCIDate',
		'NULLABLE'	=> 1,
		'VARLENGTH'	=> 0
	},
	'void'	=> {
		'IN'		=> 'void',
		'RETURN'	=> 'void'
	}
);

# prefix for C functions to avoid name clashes with standard C library
$c_prefix = "EP_";

__END__

### AUTOLOADED SUBROUTINES ###

# create_wrapper(proto,[lib])
# create C wrapper function in trusted code directory based on prototype
# and optional library
sub create_wrapper
{
	my ($proto, $lib) = @_;

	# @args holds all information about each argument
	# @args = ( { spec => x, type => x, inout => x, carg => x } )
	my @args;

	# stuff extracted from prototype
	my ($subtype, $name, $argstr, $retstr, $rettype);

	# if prototype is valid, write out C wrapper to trusted directory
	# prototype format: SUBTYPE name([arg1[,arg2,...]]) [RETURN type]

	# sub with arguments
	if ($proto =~ /^(FUNCTION|PROCEDURE)\s+([\w\d_\-]+)\(\s*([^\}]+)\s*\)(.*)\s*$/oi) {
		$subtype = "EP_SUBTYPE_".uc($1);
		$name = $2;
		$argstr = $3;
		$retstr = $4;
	}
	# sub with no arguments
	elsif ($proto =~ /^(FUNCTION|PROCEDURE)\s+([\w\d_\-]+)(?:\s+(.+))*$/oi) {
		$subtype = "EP_SUBTYPE_".uc($1);
		$name = $2;
		$retstr = $3;
	}
	else {
		die "invalid prototype";
	}

	# get return type, if any
	if ($retstr =~ /return\s+([\w\d_\-]+)/i) {
        	$rettype = uc($1);
	}
	else {
		if ($subtype eq "EP_SUBTYPE_FUNCTION") {
			die "function has no return type";
		}
		$rettype = 'void';
	}

	my @a = split(/,\s*/, $argstr);
	my $n = 0;

	# convert prototype to C arguments
	foreach (@a) {
		my ($argname, $inout, $type);
		if (/^([\w_]+)\s+IN\s+OUT\s+(.+)$/i) {
			$argname = $1;
			$inout = "IN OUT";
			$type = $2;
		}
		else {
			($argname, $inout, $type) = split(/\s+/);
		}
		$type = uc($type);
		unless (exists $typemap{$type}) {
			die "unsupported datatype: $type";
		}
		$inout = uc($inout);
		my $ctype = $typemap{$type}{$inout};
		$args[$n]{'spec'} = $_;
		$args[$n]{'name'} = $argname;
		$args[$n]{'type'} = $type;
		$args[$n]{'inout'} = $inout;
		my $tmp = "$ctype arg$n";
		if ($typemap{$type}{'NULLABLE'}) {
			if ($inout =~ /OUT/) {
				$tmp .= ", OCIInd *is_null_$n";
			}
			else {
				$tmp .= ", OCIInd is_null_$n";
			}
		}
		if ($typemap{$type}{'VARLENGTH'}) {
			if ($inout =~ /OUT/) {
				$tmp .= ", sb4 *length_$n, sb4 *maxlen_$n";
			}
			else {
				$tmp .= ", sb4 length_$n";
			}
		}
		$args[$n]{'carg'} = $tmp;
		$n++;
	}
	my $cargstr = join(', ', map($_->{'carg'}, @args));
	$cargstr = ", $cargstr" if $n;

	# result declaration and fatal return statement
	my $return_fatal;
	unless (exists $typemap{$rettype} || $rettype eq 'void') {
		die "unsupported return type: $rettype";
	}
	my $crettype = $typemap{$rettype}{'RETURN'};
	my $result_dec = "$crettype res;";
	if ($crettype eq 'void') {
		$return_fatal = "return";
		$result_dec = "";
	}
	elsif ($crettype eq 'int' || $crettype eq 'float') {
		$return_fatal = "return(0)";
	}
	else {
		$return_fatal = "return(NULL)";
	}

	# write to file in trusted code directory
	local *CODE;
	my $dir = ExtProc::config('trusted_code_directory');
	open(CODE, '>', File::Spec->catfile($dir, $name . '.c' ))
		or die $!;

#############################################################################
# here lies ugliness -- start of C code
#############################################################################

	# generate C wrapper source file
	print CODE <<_DONE_;
/* THIS FILE IS AUTOGENERATED -- CHANGES MAY BE LOST */

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

/* Perl headers */
#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>

#include "extproc_perl.h"
#ifdef __cplusplus
}
#endif

/* per-session context -- contains all the globals from version 1 */
extern EP_CONTEXT my_context;

_DONE_

	# don't need return indicator for procedures
	if ($rettype eq 'void') {
		print CODE "$crettype $c_prefix$name(OCIExtProcContext *ctx $cargstr)\n";
	}
	else {
		print CODE "$crettype $c_prefix$name(OCIExtProcContext *ctx, OCIInd *ret_ind $cargstr)\n";
	}

	print CODE <<_DONE_;
{
	int nret;
	short ind;
	SV *sv, *svcache[$#args+1];
	char *fqsub, *tmp;
	EP_CONTEXT *c;
	EP_CODE code;
	STRLEN len;
	$result_dec

	dTHX;

	dSP;

	c = &my_context;

	_ep_init(c, ctx);
_DONE_

	if ($rettype eq 'void') {
		print CODE "\tEP_DEBUGF(c, \"IN (user defined) $c_prefix$name(%p, ...)\", ctx);\n";
	}
	else {
		print CODE "\tEP_DEBUGF(c, \"IN (user defined) $c_prefix$name(%p, %p, ...)\", ctx, ret_ind);\n";
	}

	print CODE <<_DONE_;
	EP_DEBUG(c, "-- prototype: $proto");

	c->subtype = $subtype;

/* FOR FUTURE USE
 * you can't compile a C function with a colon in its name, so we don't need
 * package_subs protection yet */
#if 0
	/* don't allow fully qualified subroutine name if package_subs is off */
	/* exception is ExtProc::* */
	if (strchr("$name", ':') && !c->package_subs) {
		/* keep string compare inside the block for performance */
		if (strncmp(sub, "ExtProc::", 9)) {
			ora_exception(c, "invalid subroutine");
			$return_fatal;
		}
	}
#endif

	/* start perl interpreter if necessary */
	if (!c->perl) {
		c->perl = pl_startup(c);
		if (!c->perl) {
_DONE_

	if ($rettype ne 'void') {
		print CODE "\t\t\t*ret_ind = OCI_IND_NULL;\n";
	}

	print CODE <<_DONE_;
			$return_fatal;
		}
	}
	EP_DEBUG(c, "RETURN $c_prefix$name");

	SPAGAIN; /* in case we started interpreter after declaring SP */
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);

_DONE_

#############################################################################
# convert arguments to perl types and push onto stack
#############################################################################

	foreach my $n (0..$#args) {
		print CODE "\t/* push arg$n ($args[$n]{'spec'}) onto stack */\n";
		if ($typemap{$args[$n]{'type'}}{'NULLABLE'}) {
			if ($args[$n]{'inout'} eq 'IN') {
				print CODE <<_DONE_;
	if (is_null_$n == OCI_IND_NULL) {
		sv = sv_2mortal(newSVsv(&PL_sv_undef));
	}
	else {
_DONE_
			}
			else {
				if ($args[$n]{'type'} eq 'VARCHAR2') {
					if ($args[$n]{'inout'} eq 'OUT') {
						print CODE <<_DONE_;
	sv = sv_2mortal(newSVsv(&PL_sv_undef));
	{ /* placeholder brace */
_DONE_
					}
					else {
						print CODE <<_DONE_;
	if (*is_null_$n == OCI_IND_NULL) {	
		sv = sv_2mortal(newSVsv(&PL_sv_undef));
	}
	else {
_DONE_
					}
				}
				else {
					print CODE "\t{ /* placeholder brace */\n";
				}
			}
		}
		my $star = ($args[$n]{'inout'} =~ /OUT/) ? "*" : "";
		if ($args[$n]{'carg'} =~ /^char /) {
			if ($args[$n]{'inout'} =~ /IN/) {
				# for IN modes
				print CODE "\tsv = sv_2mortal(newSVpvn(arg$n, ${star}length_$n));\n";
			}
			else {
				# for IN OUT & OUT modes
				print CODE "\tsv = sv_newmortal();\n";
			}
		}
		elsif ($args[$n]{'carg'} =~ /^int /) {
			print CODE "\tsv = sv_2mortal(newSViv(${star}arg$n));\n";
		}
		elsif ($args[$n]{'carg'} =~ /^float /) {
			print CODE "\tsv = sv_2mortal(newSVnv(${star}arg$n));\n";
		}
		elsif ($args[$n]{'carg'} =~ /^OCIDate /) {
			print CODE <<_DONE_;
	sv = sv_newmortal();
	sv_setref_pv(sv, "ExtProc::DataType::OCIDate", arg$n);
	if (*is_null_$n == OCI_IND_NULL) {
		set_null(arg$n);
	}
	else {
		clear_null(arg$n); /* in case we used this address before */
	}
_DONE_
		}
		else {
			die "unsupported C datatype: $args[$n]{'carg'} (was $args[$n]{'spec'})";
		}

		print CODE <<_DONE_;
	svcache[$n] = sv;
	if (c->tainting) {
		SvTAINTED_on(sv);
	}
_DONE_
		if ($typemap{$args[$n]{'type'}}{'NULLABLE'}) {
			print CODE "\t}\n";
		}

		# IN OUT & OUT types are always passed as references
		# leave SV alone if it's already a reference
		if ($args[$n]{'inout'} =~ /OUT/) {
			print CODE "\tXPUSHs(sv_isobject(sv) ? sv : newRV_noinc(sv));\n";
		}
		else {
			print CODE "\tXPUSHs(sv);\n";
		}
	}

#############################################################################
# parse and run subroutine
#############################################################################

	print CODE <<_DONE_;
	PUTBACK;

	fqsub = parse_code(c, &code, "$name");
	EP_DEBUG(c, "RETURN (user defined) $c_prefix$name");
	if (!fqsub) {
_DONE_
		if ($rettype ne 'void') {
			print CODE "\t\t*ret_ind = OCI_IND_NULL;\n";
		}

		print CODE <<_DONE_;
		$return_fatal;
	}

	EP_DEBUG(c, "-- about to call call_pv()");
	nret = call_pv(fqsub, G_SCALAR|G_EVAL);
	EP_DEBUGF(c, "-- call_pv() returned %d", nret);
	if (SvTRUE(ERRSV)) {
		EP_DEBUGF(c, "-- ERRSV is defined: %s", SvPV(ERRSV, PL_na));
		ora_exception(c, SvPV(ERRSV, PL_na));
		$return_fatal;
	}
	SPAGAIN;
_DONE_

#############################################################################
# process IN OUT & OUT return values
#############################################################################

	# copy values to IN OUT and OUT args
	foreach my $n (0..$#args) {
		if ($args[$n]{'inout'} =~ /OUT/) {
			if ($args[$n]{'carg'} =~ /^char /) {
				print CODE <<_DONE_;
	if (!SvOK(svcache[$n])) {
		*is_null_$n = OCI_IND_NULL;
	}
	else {
		*is_null_$n = OCI_IND_NOTNULL;
		tmp = SvPV(svcache[$n], len);
		if (len > *maxlen_$n) {
			EP_DEBUGF(c, "maxlen = %d, len = %d", *maxlen_$n, len);
			ora_exception(c, "length of arg$n exceeds maximum length for parameter");
			$return_fatal;
		}
		Copy(tmp, arg$n, len, char);
		*length_$n = len;
	}
_DONE_
			}
			elsif ($args[$n]{'carg'} =~ /^OCIDate /) {
				print CODE <<_DONE_;
	/* DATE types are passed as pointers, so no need to copy again */
	*is_null_$n = is_null(arg$n) ? OCI_IND_NULL : OCI_IND_NOTNULL;
_DONE_
			}
			elsif ($args[$n]{'carg'} =~ /^int /) {
				print CODE <<_DONE_;
	*arg$n = SvIV(svcache[$n]);
	*is_null_$n = SvOK(svcache[$n]) ? OCI_IND_NOTNULL : OCI_IND_NULL;
_DONE_
			}
			elsif ($args[$n]{'carg'} =~ /^float /) {
				print CODE <<_DONE_;
	*arg$n = SvNV(svcache[$n]);
	*is_null_$n = SvOK(svcache[$n]) ? OCI_IND_NOTNULL : OCI_IND_NULL;
_DONE_
			}
			else {
				die "unsupported C datatype: $args[$n]{'carg'} (was $args[$n]{'spec'})";
			}
		}
	}

#############################################################################
# return from a procedure
#############################################################################

	# procedures don't return values
	if ($rettype eq 'void') {
		print CODE <<_DONE_;
	/* clean up stack and return */
	PUTBACK;
	FREETMPS;
	LEAVE;
	return;
}
_DONE_
	}

#############################################################################
# convert values back to oracle types and return value from a function
#############################################################################

	# functions do return values
	else {
		print CODE <<_DONE_;

	/* grab return value off the stack */
	sv = POPs;
_DONE_
		if ($crettype =~ /char\s*\*/) {
			print CODE <<_DONE_;
	if (SvOK(sv)) {
		tmp = SvPV(sv,len);
		New(0, res, len+1, char);
		Copy(tmp, res, len, char);
		res[len] = '\\0';
		*ret_ind = OCI_IND_NOTNULL;
	}
	else {
		*ret_ind = OCI_IND_NULL;
	}
_DONE_
		}
		elsif ($crettype =~ /OCIDate\s*\*/) {
			print CODE <<_DONE_;
	res = ($crettype)SvIV(SvRV(sv));
	*ret_ind = is_null(sv) ? OCI_IND_NULL : OCI_IND_NOTNULL;
_DONE_
		}
		elsif ($crettype eq 'int') {
			print CODE <<_DONE_;
	res = SvIV(sv);
	*ret_ind = SvTRUE(sv) ? OCI_IND_NOTNULL : OCI_IND_NULL;
_DONE_
		}
		elsif ($crettype eq 'float') {
			print CODE <<_DONE_;
	res = SvNV(sv);
	*ret_ind = SvTRUE(sv) ? OCI_IND_NOTNULL : OCI_IND_NULL;
_DONE_
		}
		else {
			die "unknown return type: $crettype";
		}

		print CODE <<_DONE_;

	/* clean up stack and return */
	PUTBACK;
	FREETMPS;
	LEAVE;

	return(res);
}
_DONE_
	}
	close(CODE);

#############################################################################
# generate and save DDL
#############################################################################

	# external procedure DDL
	my $sql;
	my $ddl_format = ExtProc::config('ddl_format');
	if ($ddl_format == 0) {
		$sql = 'CREATE OR REPLACE ';
	}
	else {
		$sql = "-- for package specification\n$proto\n";
		$sql .= "-- for package body\n";
	}
	$sql .= "$proto\n";
	$sql .= "AS EXTERNAL NAME \"EP_$name\"\n";
	$sql .= "LIBRARY \"" . ($lib ? $lib : "PERL_LIB") . "\"\n";
	$sql .= "WITH CONTEXT\n";
	$sql .= "PARAMETERS (\n";
	$sql .= "   CONTEXT";
	$sql .= ",\n   RETURN INDICATOR BY REFERENCE"
		unless ($rettype eq 'void');
	foreach my $n (0..$#args) {
		my $name = $args[$n]{'name'};
		my $type = $args[$n]{'type'};
		my $inout = $args[$n]{'inout'};
		$sql .= ",\n   $name $typemap{$type}{'PARAMTYPE'}";
		if ($typemap{$type}{'NULLABLE'}) {
			$sql .= ",\n   $name INDICATOR short";
		}
		if ($typemap{$type}{'VARLENGTH'}) {
			$sql .= ",\n   $name LENGTH sb4";
			if ($inout =~ /OUT/) {
				$sql .= ",\n   $name MAXLEN sb4";
			}
		}
	}
	$sql .= "\n);";
	if ($ddl_format == 0) {
		$sql .= "\n/\n";
	}

	# write DDL to file
	local *DDL;
	open(DDL, '>', File::Spec->catfile($dir, $name . '.sql' ))
		or die $!;
	print DDL "$sql\n";
	close(DDL);

	# output DDL ("set serveroutput on" to see it in sqlplus)
	put_line($_) foreach (split(/[\r\n]+/, $sql));
}

# import_code(name, filename, [proto])
# import code from a file in the trusted code directory and optionally create
# a C wrapper based on the supplied prototype
sub import_code
{
	my ($name, $file, $proto) = @_;

	# DML -- MUST BE CALLED AS A PROCEDURE
	if (!ExtProc::is_procedure) {
		ExtProc::ora_exception('import_code must be called as a procedure!');
		return;
	}

	if ($name eq '') {
		ExtProc::ora_exception('import_code: empty subroutine name');
		return;
	}

	# untaint arguments, since we're being called from oracle
	if ($name =~ /^([A-z\d\-_]+)$/) {
		$name = $1;
	}
	else {
		ExtProc::ora_exception('illegal characters in subroutine name');
		return;
	}
	if ($file =~ /^([\w\.\-\_]+)$/) {
		$file = $1;
	}
	elsif (!defined($file)) {
		$file = "${name}.pl";
	}
	else {
		ExtProc::ora_exception('illegal characters in filename');
		return;
	}

	# what's our code table and trusted code directory?
	my $table = ExtProc::config('code_table');
	my $dir = ExtProc::config('trusted_code_directory');

	my $path = File::Spec->catfile($dir, $file);
	my $size = (stat($path))[7];
	if ($size > ExtProc::config('max_code_size')) {
		ExtProc::ora_exception("file too large for import ($size bytes)");
		return;
	}

	# read code from file
	my ($code, $line);
	local *CODE;
	open(CODE, $path) or die "failed to open code file: $!";
	while(defined($line = <CODE>)) {
		$code .= $line;
	}
	close(CODE);

	# get current version number, if any
	my $dbh = ExtProc->dbi_connect;
	my $sth = $dbh->prepare("select nvl(version, 0) from $table where name = ?");
	$sth->execute($name);
	ExtProc::ep_debug("rows=".$sth->rows);
	my $version = ($sth->fetchrow_array)[0];
	$sth->finish;

	# delete existing code if it exists
	$sth = $dbh->prepare("delete from $table where name = ?");
	$sth->execute($name);
	$sth->finish;

	# find prototype, if any
	if (!$proto && $code =~ /^((?:FUNCTION|PROCEDURE)\s+$name.*)/im) {
		$proto = $1;
	}

	# import code into database, incrementing version
	$sth = $dbh->prepare("insert into $table (name, plsql_spec, language, version, code) values(?, ?, 'Perl5', ?, ?)");
	$sth->execute($name, $proto, $version+1, $code);
	$sth->finish;

	# create C wrapper if we have a prototype
	$proto && create_wrapper($proto);
}

# drop_code(name)
# silently remove code from code table
sub drop_code
{
	my $name = shift;

	# DML -- MUST BE CALLED AS A PROCEDURE
	if (!ExtProc::is_procedure) {
		ExtProc::ora_exception('drop_code must be called as a procedure!');
		return;
	}

	# what's our code table?
	my $table = ExtProc::config('code_table');

	my $dbh = ExtProc->dbi_connect;
	my $sth = $dbh->prepare("delete from $table where name = ?");
	$sth->execute($name);
	$sth->finish;
}
