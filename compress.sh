TYEAR=`basename $0 | cut -c1-4` # Target Year
TDIR=`basename $0`
TDIR=${TDIR%.sh}

cd /home/seiyo/public_html/photo/${TYEAR}/
tar cf - ${TDIR} | gzip -c

