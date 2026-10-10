#!/bin/bash
# откатить сцены, где поменялись только unique_id
cd "$(dirname "$0")/.."
for f in $(git status --short scenes/ | grep "^ M" | awk '{print $2}'); do
  n=$(git diff $f | grep '^[-+][^-+]' | grep -v unique_id | wc -l)
  if [ "$n" = "0" ]; then git checkout -q $f; echo "откат $f"; else echo "изменено $f ($n)"; fi
done
