#!/usr/bin/env bash

for f in $(find ./StrongBox -name '*.m' -or -name '*.h'); do uncrustify --replace --no-backup -l OC -c uncrustify.cfg $f; done

