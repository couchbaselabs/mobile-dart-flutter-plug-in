#! /usr/bin/env awk -f

BEGIN               { print "; GENERATED BY generate_exports.sh -- DO NOT EDIT"; print ""; print "EXPORTS"; print "" }
/^[A-Za-z_]/        { print $0; next }
