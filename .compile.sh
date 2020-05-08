#! /bin/bash

perl_include_dir=$(perl -MConfig -e'print $Config{archlib}')"/CORE"

swig_cmd=swig2.0
include=/tmp/gsl-master/include
if [[ $HOSTNAME == "hakon-Precision-7530" ]] ; then
    swig_cmd=swig
    include=/usr/include
fi
"$swig_cmd" -w451,454 -perl5 -I"$include" SF.i 

name=SF
gcc -I${perl_include_dir} -c -fPIC -g3 -o SF_wrap.o SF_wrap.c
gcc -shared SF_wrap.o -o "$name".so -lm -lgsl -lgslcblas
mkdir -p lib/GSL
mv "$name".pm lib/GSL
mkdir -p lib/arch/auto/GSL/"$name"
mv "$name".so lib/arch/auto/GSL/"$name"
