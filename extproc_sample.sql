CREATE OR REPLACE LIBRARY PERL_LIB IS
   '/u01/app/oracle/product/8.1.7/lib/extproc_perl.so'
/

show errors

CREATE OR REPLACE FUNCTION perl (
   sub IN VARCHAR2, arg1 in VARCHAR2 default NULL, arg2 in VARCHAR2 default NULL, arg3 in VARCHAR2 default NULL, dummy in VARCHAR2 default NULL)
RETURN STRING AS
EXTERNAL NAME "ora_perl_sub"
LIBRARY "PERL_LIB"
WITH CONTEXT
PARAMETERS (
   CONTEXT,
   RETURN INDICATOR BY REFERENCE,
   sub string,
   arg1 string,
   arg1 INDICATOR short,
   arg2 string,
   arg2 INDICATOR short,
   arg3 string,
   arg3 INDICATOR short,
   dummy string,
   dummy INDICATOR short);
/

show errors
