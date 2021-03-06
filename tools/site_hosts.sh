#!/bin/bash

#
#  check all domains mentioned in sites.csv file exist in a set of mappings files
#
cmd=$(basename $0)
sites="data/sites.csv"
aka=""

usage() {
    echo "usage: $cmd [opts] [mappings.csv ...]" >&2
    echo "    [-a|--also-aka]             also generate aka hosts" >&2
    echo "    [-s|--sites $sites] sites file" >&2
    echo "    [-?|--help]                 print usage" >&2
    exit 1
}

while test $# -gt 0 ; do
    case "$1" in
    -a|--also-aka) shift ; aka=y ; continue ;;
    -s|--sites) shift; sites="$1" ; shift ; continue ;;
    -\?|-h|--help) usage ;;
    --) shift ; break ;;
    -*) usage ;;
    esac
    break
done


#
#  sites.csv
#
#  1     2   3                4             5     6    7
#  Site,Host,Redirection Date,TNA Timestamp,Title,FURL,Aliases, ...
#

cat "$sites" | 
    tail -n +2 |
    cut -d , -f 2,7 |
    sed -e 's/,/ /g' -e 's/  */\
/g' |
    sed -e '/^ *$/d' |
    sort -u |
    while read host
    do
        echo $host
        if [ -n "$aka" ] ; then
            aka=$(echo $host | sed -e 's/^/aka-/' -e 's/^aka-www/aka/')
            echo $aka
        fi
    done |
    sort -u

exit 0
