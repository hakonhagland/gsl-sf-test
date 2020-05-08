#! /bin/bash

perl_include_dir=$(perl -MConfig -e'print $Config{archlib}')"/CORE"

swig -w451,454 -perl5 -I/usr/include SF.i 

name=SF
gcc -I${perl_include_dir} -c -fPIC -g3 -o SF_wrap.o SF_wrap.c
gcc -shared SF_wrap.o -o "$name".so -lm -lgsl -lgslcblas
mkdir -p lib/GSL
mv "$name".pm lib/GSL
mkdir -p lib/arch/auto/GSL/"$name"
mv "$name".so lib/arch/auto/GSL/"$name"
