#!/bin/sh

function usage
{
	echo "usage:"
	echo "$0 command options"
	echo "$0 check options size"
	echo "$0 mkhtml options size"
	echo "commands are: check, mkhtml"
	echo "$0 check"
	echo "$0 mkhtml [-conf file ] [-migrate] size"
	echo "size : size of x-size"
}


# Sub Functions
function CheckLinks
{
	local rc=0
	echo "working directory is `pwd`"
	
	echo "checking download.cgi"
	if [ ! -L ${yyyymmdd}.cgi ]; then
		echo "${yyyymmdd}.cgi is not exist."
		rc=1
	fi
	if [ ! -L ${LINKEDCOMPRESSSH} ]; then
		echo "${LINKEDCOMPRESSSH} is not exist."
		rc=1
	fi
	
	echo "checking controlphoto.cgi"
	if [ ! -L ${CWD}/${ControlPhotoCGIPath##*/} ]; then
		echo "${CWD}/${ControlPhotoCGIPath##*/} is not exist."
		rc=1
	fi
	
	echo "checking album.js"
	if [ ! -L ${CWD}/${JavascriptPath##*/} ]; then
		echo "${CWD}/${JavascriptPath##*/} is not exist."
		rc=1
	fi

	return ${rc}
}
	
function MakeLinks
{
	echo "working directory is `pwd`"
	
	echo "making download.cgi"
	ln -sf ${DownloadCGIPath} ${yyyymmdd}.cgi
	ln -sf ${COMPRESSSH} ${LINKEDCOMPRESSSH}
	
	echo "making controlphoto.cgi"
	ln -sf ${ControlPhotoCGIPath} ${CWD}
	
	echo "making album.js"
	ln -sf ${JavascriptPath} ${CWD}
	
	CheckLinks
	if [ $? -ne 0 ];then
		echo "Making links failed."
	fi

}

function CountFileNum
{
	echo "checking the number of files"
	local ORGFILENUM=`find -L ${CWD} -type f | egrep -i "(${SearchImgExt}|${SearchMovieExt})$" | grep -v "thumb" | wc -l`
	local THUMBFILENUM=`find -L ${CWD} -type f | egrep -i "_${XSize}${OutputImgExt}$" | grep "thumb" | wc -l`
	echo " original file: ${ORGFILENUM}"
	echo " thumbnail    : ${THUMBFILENUM}"

	if [ ${ORGFILENUM} -ne ${THUMBFILENUM} ]; then
		ThisStatus=${NotFullThumbnailStatus}
		return 1
	else
		ThisStatus=${FullThumbnailStatus}
		return 0
	fi

}

function ReadStatusFile
{
	if [ -r "${StatusFile}" ]; then
		local line
		while read -r line
		do
			case "${line%%:*}" in
				"Status")
					FileStatus=${line##*: }
					;;
				"StructType")
					FileStructType=${line##*: }
					;;
				"${FinishedText}") # remove after migration from old version
					FileStatus=${FinishedStatus}
					FileStructType="0.1"
					;;
				*)
					;;
			esac
		done < ${StatusFile}
	fi
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
	cat <<BODY
<a href=${1}>
 <img src="${2}"/>
</a>
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
	local PhotoDate=`get_photo_date ${File}`

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

	local FormattedFile=${File#${CWD}/}
	if [ ! -d ${ThumbDir}/${FormattedFile%/*} ]; then
		mkdir -p ${ThumbDir}/${FormattedFile%/*}
	fi
	local ThumbFile=${ThumbDir}/${FormattedFile%${AllExt}}_${XSize}${OutputImgExt}
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

function CheckFileMode
{
	if [ -n "$(find . -type f -perm 000)" ];then
		return 1
	else
		return 0
	fi
}

function ChangeFileMode
{
	chmod -R u+rw,g+r,o+r *
	CheckFileMode
	return $?
}

function MkHtml
{
	if [ "${FileStatus}" = "${FinishedStatus}" ] && [ "${ThisStatus}" = "${FullThumbnailStatus}" ] && ( [ "${MigrateFlag}" != "1" ] || [ "${MigrateFlag}" = "1" -a "${StructType}" = "${ThisStructType}" ] ) ; then
		echo "already finished : skipped."
		return 0
	fi


	if [ ! -d ${ThumbDir} ]; then
		mkdir ${ThumbDir}
	fi

	html_header > ${TopPage}
	body_all_index >> ${TopPage}
	html_header > ${AllPhotoPage}

	local INDEXCOUNTDate=0
	local INDEXCOUNTUnknown=0
	# convert image files and add entry to index file

	for File in `find -L ${CWD} -name "${ThumbDir}" -prune -o -type f -print | egrep -i "(${SearchImgExt}|${SearchMovieExt})$" | sort`
	do
		convert_and_html
	done

	if [ ! -z ${CurPage} ]; then
	
		html_footer >> ${CurPage}
	fi
	html_footer >> ${TopPage}
	html_footer >> ${AllPhotoPage}
}


function Mode
{
	# mode check
	while [ -n "$1" ]
	do
		case $1 in
			"check")
				shift
				CheckMode $@
				exit $?
				;;
			"mkhtml")
				shift
				MkHtmlMode $@
				exit $?
				;;

			*)
				usage
				exit 1
				;;
		esac
	done
}

# Initialize Global Variables
FileStatus=
FileStructType=
ThisStatus=
ThisStructType="0.9"
FinishedStatus="Finished"
NotFullThumbnailStatus="Not Full Thumbnail"
FullThumbnailStatus="Full Thumbnail"

# Main Functions
function CheckMode
{
	for ARGV in "$@";do 
		case "${ARGV}" in
			"-conf"|"-c")
				shift
				ConfPath=$1
				shift
				;;
		esac
	done

	. ${ConfPath:=$(dirname $0)/photoalbum.conf}
	ReadStatusFile

	if [ $# -ne 0 ]; then
		usage
		exit 1
	fi

	local rc=0
	CheckLinks
	rc=`expr $rc + $?`

	CountFileNum
	rc=`expr $rc + $?`

	CheckFileMode
	rc=`expr $rc + $?`

	# Write Status
	echo "Status: ${ThisStatus}" > ${StatusFile}
	# StructType will not be changed.
	echo "StructType: ${FileStructType}" >> ${StatusFile}

	return ${rc}
}

function MkHtmlMode
{
	for ARGV in "$@";do 
		case "${ARGV}" in
			"-conf"|"-c")
				shift
				ConfPath=$1
				shift
				;;
			"-migrate")
				MigrateFlag=1
				shift
				;;
		esac
	done

	. ${ConfPath:=$(dirname $0)/photoalbum.conf}
	ReadStatusFile

	if [ $# -eq 1 ]; then
		XSize=$1 # Override XSize
	else
		usage
		exit 1
	fi

	local rc=0
	MakeLinks
	rc=`expr $rc + $?`

	CountFileNum
	rc=`expr $rc + $?`

	ChangeFileMode
	rc=`expr $rc + $?`

	# Make html files
	MkHtml

	# Write Status
	echo "Status: ${FinishedStatus}" > ${StatusFile}
	echo "StructType: ${ThisStructType}" >> ${StatusFile}

	return ${rc}
}

Mode $@

