#!/bin/sh

mydir=`dirname "$0"`

export LD_LIBRARY_PATH=$mydir/libs:$LD_LIBRARY_PATH

cd $mydir

./drastic "$1"

