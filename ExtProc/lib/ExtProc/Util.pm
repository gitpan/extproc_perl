# $Id: Util.pm,v 1.12 2004/04/14 23:39:53 jeff Exp $

package ExtProc::Util;

use 5.6.1;
use strict;
use warnings;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);
our %EXPORT_TAGS = ( 'all' => [ qw(
	&match
	&substitute
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw(
);
our $VERSION = '1.99_09';

use ExtProc;

# match(string, pattern)
# returns 1 on match, 0 on no match
sub match
{
	my ($string, $pattern) = @_;

	if ($pattern eq '') {
		ExtProc::ora_exception("match: empty pattern");
		return 0;
	}

	return ($string =~ /$pattern/) ? 1 : 0;
}

# substitute(string, pattern, replace)
# returns string with substitutions
sub substitute
{
	my ($string, $pattern, $replace) = @_;

	# untaint everything -- sort of dangerous
	if ($string =~ /(.*)/) {
		$string = $1;
	}
	if ($pattern =~ /(.*)/) {
		$pattern = $1;
	}
	if ($replace =~ /(.*)/) {
		$replace = $1;
	}

	if ($pattern eq '') {
		ExtProc::ora_exception("substitute: empty pattern");
		return 0;
	}

	$string =~ s/$pattern/$replace/g;

	return $string;
}
