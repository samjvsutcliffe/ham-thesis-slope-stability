#!/bin/bash
#export OMP_PROC_BIND=spread,close
#export BLIS_NUM_THREADS=1
export REFINE=1
read -p "Do you want to clear previous data? (y/n)" yn
case $yn in
    [yY] ) echo "Removing data";rm data/*; break;;
    [nN] ) break;;
esac
set -e
module load aocc/5.0.0
module load aocl/5.0.0
sbcl --dynamic-space-size 16000 --load "build.lisp" --quit

for h in 50 100 150
do
    for f in 0.4 0.3 0.2 0.1 0
    do
        export HEIGHT=$h
        export FLOATATION=$f
        sbatch batch_template_worker.sh
    done
done
