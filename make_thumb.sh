#!/bin/sh

function usage
{
	echo "usage:"
	echo "$0 [-check] extension size"
	echo "$0 [-newonly] [-conf path] extension size"
	echo "extension : extension with period"
	echo "size : size of x-size"
}

# mode check
while [ "$1" != "" -a ${1:0:1} = "-" ]
do
	case $1 in
		"-check")
			CheckOnlyFlag=1
			shift
			;;
		"-newonly")
			NewOnlyFlag=1
			shift
			;;
		"-conf")
			shift
			ConfPath=$1
			shift
			;;
	esac
done

Ext=$1
XSize=$2

if [ $# != 2 ]; then
	usage
	exit 1
fi

. ${ConfPath:=$(dirname $0)/photoalbum.conf}

function main
{
	echo "working directory is `pwd`"
	
	echo "making download.cgi"
	ln -sf ${DownloadCGIPath} ${yyyymmdd}.cgi
	ln -sf ${COMPRESSSH} ${LINKEDCOMPRESSSH}
	
	echo "making controlphoto.cgi"
	ln -sf ${ControlPhotoCGIPath} .
	
	echo "making album.js"
	ln -sf ${JavascriptPath} .
	
	echo "changing mode"
	change_mode
	
	echo "checking the number of files"
	ORGFILENUM=`find -L ${CWD} -type f | egrep -i "(${SearchImgExt}|${SearchMovieExt})$" | grep -v "thumb" | wc -l`
	THUMBFILENUM=`find -L ${CWD} -type f | egrep -i "_${XSize}${OutputImgExt}$" | grep "thumb" | wc -l`
	echo " original file: ${ORGFILENUM}"
	echo " thumbnail    : ${THUMBFILENUM}"

	if [ ${CheckOnlyFlag} = 1 ]; then
		echo "checked."
		exit 0
	fi

	if [ ${NewOnlyFlag} = 0 -a ${ORGFILENUM} -ne ${THUMBFILENUM} ];then
	
		if [ -e ${StatusFile} ];then
			rm -f ${StatusFile}
		fi
	fi


	if [ "`cat ${StatusFile}`" = "${FinishedText}" ]; then
		echo "already finished : skipped."
		exit 0
	fi

	if [ `basename $0` = "mkthumbonly" ]; then
		ThumbOnlyFlag=1
	fi

	if [ ! -h "`dirname $0`/mkthumbonly" ]; then
		ln -s `basename $0` "`dirname $0`/mkthumbonly"
	fi
	if [ ! -d ${ThumbDir} ]; then
		mkdir ${ThumbDir}
	fi

	html_header > ${TopPage}
	body_all_index >> ${TopPage}
	html_header > ${AllPhotoPage}

	INDEXCOUNTDate=0
	INDEXCOUNTUnknown=0
	# convert image files and add entry to index file
	if [ -z "`find -L ${CWD} -name \"${ThumbDir}\" -prune -o -type f -print | egrep -i \"(${SearchImgExt})$\" `" ]; then
		ThumbOnlyFlag=1
	fi

	if [ $ThumbOnlyFlag = 0 ]; then
		for File in `find -L ${CWD} -name "${ThumbDir}" -prune -o -type f -print | egrep -i "(${SearchImgExt}|${SearchMovieExt})$" | sort`
		do
			convert_and_html
		done
	elif [ ${ThumbOnlyFlag} = 1 ]; then
		for File in `find -L ${ThumbDir} -type f -print | egrep -i "(${SearchImgExt}|${SearchMovieExt})$" | sort`
		do
			convert_and_html
		done
	else
		echo "ERROR: in here."
	fi

	if [ ! -z ${CurPage} ]; then
	
		html_footer >> ${CurPage}
	fi
	html_footer >> ${TopPage}
	html_footer >> ${AllPhotoPage}

	echo ${FinishedText} > ${StatusFile}

}

function html_header
{
        cat <<HEADER
<html>
<head>
<title>album</title>
</head>
<body>
<a href=..>Parent Directory</a><br/>
HEADER
}

function html_footer
{
        cat <<FOOTER 
</body>
</html>
FOOTER
}

function html_body
{
	case $ThumbOnlyFlag in
		0)
			body_thumb_original $*
			;;
		1)
			body_thumb_only $*
			;;
		*)
			body_thumb_original $*
			;;
	esac
}

function body_thumb_original
{
	cat <<BODY
<a href=${1}>
 <img src="${2}"/>
</a>
BODY
}

function body_thumb_only
{
	cat <<BODY
 <img src="${1}"/>
BODY
}

function body_all_index
{
	cat <<BODY
<a href="${yyyymmdd}.cgi">Download All files</a><br/>
<a href=${AllPhotoPage}>View All photos</a><br/>
BODY
}

function body_each_index
{
	cat <<BODY
<a href=${1}>${1}</a><br/>
BODY
}

function get_photo_date
{
	TargetFile=$1
	strings ${TargetFile} | head -n 20 > tmpfile
	grep PENTAX tmpfile > /dev/null 2>&1
	if [ $? = 0 ]; then
		egrep '^2[0-9][0-9][0-9]:[01][0-9]:[0-3][0-9]' tmpfile | tail -n 1 | awk '{print $1}' | tr ':' '_'
	else
		echo "unknown"
	fi
	rm tmpfile
}

function convert_and_html
{
	PhotoDate=`get_photo_date ${File}`
	

	if [ "${PhotoDate}" = "unknown" ]; then
		if [ ${INDEXCOUNTUnknown} -gt 0 -a "`expr ${INDEXCOUNTUnknown} % ${Per}`" = 0 ]; then
			CurPage=${IndexBase}${PhotoDate}_`printf "%03d" ${PageNumUnknown}`${IndexExt}
			html_footer >> ${CurPage}
			PageNumUnknown=${INDEXCOUNTUnknown}
		fi
		if [ "`expr ${INDEXCOUNTUnknown} % ${Per}`" = 0 ]; then
			CurPage=${IndexBase}${PhotoDate}_`printf "%03d" ${PageNumUnknown}`${IndexExt}
			body_each_index ${CurPage} >> ${TopPage}
			html_header > ${CurPage}
		fi
		CurPage=${IndexBase}${PhotoDate}_`printf "%03d" ${PageNumUnknown}`${IndexExt}
		INDEXCOUNTUnknown=`expr $INDEXCOUNTUnknown + 1`
	else
		OldPage=${CurPage}
		if [ "${PhotoDate}" != "${CurDate}" ]; then
			INDEXCOUNTDate=0
			CurDate=${PhotoDate}
			PageNumDate=${INDEXCOUNTDate}
			CurPage=${IndexBase}${PhotoDate}_`printf "%03d" ${PageNumDate}`${IndexExt}
			body_each_index ${CurPage} >> ${TopPage}
			html_header > ${CurPage}

			if [ -e "${OldPage}" ];then
				html_footer >> ${CurPage}
			fi
		elif [ ${INDEXCOUNTDate} -gt 0 -a "`expr ${INDEXCOUNTDate} % ${Per}`" = 0 ]; then
			PageNumDate=${INDEXCOUNTDate}
			CurPage=${IndexBase}${PhotoDate}_`printf "%03d" ${PageNumDate}`${IndexExt}
			body_each_index ${CurPage} >> ${TopPage}
			html_header > ${CurPage}
			if [ -e "${OldPage}" ];then
				html_footer >> ${CurPage}
			fi
		fi

		CurPage=${IndexBase}${PhotoDate}_`printf "%03d" ${PageNumDate}`${IndexExt}
		INDEXCOUNTDate=`expr $INDEXCOUNTDate + 1`
	fi

	FormattedFile=${File#${CWD}/}
	if [ ! -d ${ThumbDir}/${FormattedFile%/*} ]; then
		mkdir -p ${ThumbDir}/${FormattedFile%/*}
	fi
	ThumbFile=${ThumbDir}/${FormattedFile%${AllExt}}_${XSize}${OutputImgExt}
	if [ ${ThumbOnlyFlag} = 0 -a ! -e ${ThumbFile} ]; then
		echo "converting ${File}"
		${ConvertCmd} ${File}[0] -scale ${XSize} ${ThumbFile}
		if [ $? -ne 0 ]; then
			ThumbFile=${UNKNOWN_ICON}
		fi
	fi

	echo "adding ${FormattedFile} to html"
	html_body ${FormattedFile} ${ThumbFile} >> ${CurPage}
	html_body ${FormattedFile} ${ThumbFile} >> ${AllPhotoPage}

}

function change_mode
{
	chmod -R u+rw,g+r,o+r *
}

main
