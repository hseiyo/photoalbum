#!/bin/sh

SHELLNAMEFORTHUM="upload_thums.sh"
TARGET_EXT="jpg jpeg JPG JPEG AVI MPEG MPG MOV"

# expand target extentions
for ext in ${TARGET_EXT}; do
	COPYEXT="${COPYEXT} '{}'/*.${ext}"
done

function usage
{
	echo "usage:"
	echo "$0 [-f] dest_dir directories"
	echo "-f : overwrite fource"
}

if [ $# -lt 2 ]; then
	usage
	exit 1
fi

if [ $1 = "-f" ]; then
	FOURCEFLAG=1
	shift
fi

DestDir=$1
shift

if [ 0 != "`ssh www.sei-yo.jp \"test -d ${DestDir}; echo \\$?\"`" ]; then
	echo "directory not exist: ${DestDir}"
fi

for d in $*
do
	ALTDestDIR=${d%%@*}_${d##*@}
	if [ ! -z "${FOURCEFLAG}" -o 0 != "`ssh www.sei-yo.jp \"test -d ${DestDir}/${ALTDestDIR}; echo \\$?\"`" ]; then
		echo "uploading $d"
		ssh www.sei-yo.jp "mkdir ${DestDir}/${ALTDestDIR}"
		cat <<EOF | ssh www.sei-yo.jp "cat ${DestDir}/${ALTDestDIR}/.htaccess"
AuthType Basic
AuthName Mountain
AuthUserFile /home/seiyo/authdir/photo.pw
AuthGroupFile /home/seiyo/authdir/photo.gr
Require user init seiyo view
EOF
		if [ `basename $0` = ${SHELLNAMEFORTHUM} ]; then
			scp -r ${d}/thumbs www.sei-yo.jp:${DestDir}/${ALTDestDIR}/thumbs
		else
			cd $d
			find . -type d -exec ssh www.sei-yo.jp mkdir -p ${DestDir}/${ALTDestDIR}/{} \;
			find . -type d | xargs -I '{}' sh -c "scp ${COPYEXT} www.sei-yo.jp:${DestDir}/${ALTDestDIR}/'{}'"
			cd ..
		fi
	else
		echo "skipping $d"
	fi
done

