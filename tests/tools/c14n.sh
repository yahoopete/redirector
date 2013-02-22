#!/bin/sh

input='/tmp/test_c14n_input.csv'
output='/tmp/test_c14n_output.csv'

# test: lowercases urls

cat > $input <<!
old,new,rest,of,line
http://EXAMPLE.COM/UPPER-CASE,http://EXAMPLE.COM/TARGET,rest,of,line
!

./tools/c14n.pl < $input > $output

diff $output - <<!
old,new,rest,of,line
http://example.com/upper-case,http://EXAMPLE.COM/TARGET,rest,of,line
!

[ $? -ne 0 ] && { echo "$0: FAIL" ; exit 1; }

# test: remove fragments and query strings

cat > $input <<!
old,new,source
http://example.com#fragment,,
http://example.com?query-string,,
http://example.com?another-query-string,,
!

./tools/c14n.pl < $input > $output

diff $output - <<!
old,new,source
http://example.com,,
http://example.com,,
http://example.com,,
!

[ $? -ne 0 ] && { echo "$0: FAIL" ; exit 1; }

# test: remove trailing insignificant characters

cat > $input <<!
old,new,source
http://example.com?,,
http://example.com/,,
http://example.com#,,
!

./tools/c14n.pl < $input > $output

diff $output - <<!
old,new,source
http://example.com,,
http://example.com,,
http://example.com,,
!

[ $? -ne 0 ] && { echo "$0: FAIL" ; exit 1; }

# test: keep query string if we specify the option

cat > $input <<!
old,new,
http://example.com?query-one,,
http://example.com?query-two,,
!

./tools/c14n.pl --allow-query-string < $input > $output

diff $output - <<!
old,new,
http://example.com?query-one,,
http://example.com?query-two,,
!

[ $? -ne 0 ] && { echo "$0: FAIL" ; exit 1; }

# test: remove quoting

cat > $input <<!
old,new,
"http://example.com/spaces in url",,
!

./tools/c14n.pl < $input > $output

diff $output - <<!
old,new,
http://example.com/spaces%20in%20url,,
!

[ $? -ne 0 ] && { echo "$0: FAIL" ; exit 1; }

# test: trim spaces

cat > $input <<!
old,new,
 http://example.com,,
http://example.com ,,
%20http://example.com,,
!

./tools/c14n.pl < $input > $output

diff $output - <<!
old,new,
http://example.com,,
http://example.com,,
http://example.com,,
!

[ $? -ne 0 ] && { echo "$0: FAIL" ; exit 1; }

# test: replace &amp; with correct &

cat > $input <<!
old,new,
http://example.com/love&amp;it/,,
!

./tools/c14n.pl < $input > $output

diff $output - <<!
old,new,
http://example.com/love&it,,
!

[ $? -ne 0 ] && { echo "$0: FAIL" ; exit 1; }

echo "$0: OK"
