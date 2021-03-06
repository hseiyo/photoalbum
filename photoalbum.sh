#!/bin/bash

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
function Messages
{
	local Level=info
	local Severity=user
	if [ $# -ge 2 ]; then
		Level=$1
		shift
	fi
	case "${Level}" in
		"Error"|"err"|"Err")
			Level=err
			;;
		"Warn"|"Warning"|"warn")
			Level=warning
			;;
		"Debug"|"debug")
			Level=debug
			;;
		"Info"|"Information"|"info")
			Level=info
			;;
		*)
			Messages "Error" "Unknown level specified: ${Level}"
			Level=info
			;;
	esac

	if [ "${Level}" != "debug" -o "${Debug}" = "on" ]; then
		echo "[${Level}] $*"
		logger -t $(basename $0) -p ${Severity}.${Level} "$*"
	fi
}


function CheckLinks
{
	local rc=0
	Messages "working directory is ${CWD}"
	
	Messages "checking download.cgi"
	if [ ! -L ${yyyymmdd}.cgi ]; then
		Messages "${yyyymmdd}.cgi is not exist."
		rc=1
	fi
	if [ ! -L ${LINKEDCOMPRESSSH} ]; then
		Messages "${LINKEDCOMPRESSSH} is not exist."
		rc=1
	fi
	
	Messages "checking controlphoto.cgi"
	if [ ! -L ${CWD}/${ControlPhotoCGIPath##*/} ]; then
		Messages "${CWD}/${ControlPhotoCGIPath##*/} is not exist."
		rc=1
	fi
	
	Messages "checking album.js"
	if [ ! -L ${CWD}/${JavascriptPath##*/} ]; then
		Messages "${CWD}/${JavascriptPath##*/} is not exist."
		rc=1
	fi

	return ${rc}
}
	
function MakeLinks
{
	Messages "working directory is ${CWD}"
	
	Messages "making download.cgi"
	ln -sf ${DownloadCGIPath} ${yyyymmdd}.cgi
	ln -sf ${COMPRESSSH} ${LINKEDCOMPRESSSH}
	
	Messages "making controlphoto.cgi"
	ln -sf ${ControlPhotoCGIPath} ${CWD}
	
	Messages "making album.js"
	ln -sf ${JavascriptPath} ${CWD}
	
	CheckLinks
	if [ $? -ne 0 ];then
		Messages "Making links failed."
	fi

}

function CountFileNum
{
	Messages "checking the number of files"
	local ORGFILENUM=`find -L ${CWD} -type f | egrep -i "(${SearchImgExt}|${SearchMovieExt})$" | grep -v "thumb" | wc -l`
	local THUMBFILENUM=`find -L ${CWD} -type f | egrep -i "_${XSize}${OutputImgExt}$" | grep "thumb" | wc -l`
	Messages " original file: ${ORGFILENUM}"
	Messages " thumbnail    : ${THUMBFILENUM}"

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
	local FinishedText="Finished to make thumbs"  # remove after migration from old version.

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

	Messages "Read Status as follows:"
	Messages "Status: ${FileStatus}"
	Messages "Type: ${FileStructType}"

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
<a href="${1}">
 <img src="${2}"/>
${3}
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
<a href="${1}">${1}</a><br/>
BODY
}

function get_photo_date
{
	local TargetFile="$1"
	local ReturnDate
	strings "${TargetFile}" | head -n 30 > tmpfile
	ReturnDate=$(egrep '^2[0-9][0-9][0-9]:[01][0-9]:[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9]' tmpfile | tail -n 1 | awk '{print $1}' | tr ':' '_')
	echo ${ReturnDate:=unknown}
	rm tmpfile
}

function get_photo_time
{
	local TargetFile="$1"
	local ReturnDate
	strings "${TargetFile}" | head -n 30 > tmpfile
	ReturnDate=$(egrep '^2[0-9][0-9][0-9]:[01][0-9]:[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9]' tmpfile | tail -n 1 | awk '{print $2}')
	echo ${ReturnDate:=}
	rm tmpfile
}


function convert_and_html
{

	# unknown date image file
	# able to get the date of image file
	local PageNumLocal # is included in filename.
	local INDEXCOUNTLocal # is number of image files in same date or unknown date.

	# global variables
	# PageNumUnknown
	# INDEXCOUNTUnknown
	# PageNumDate
	# INDEXCOUNTDate
	# CurDate 

	# This function is executed for each image file.
	local PhotoDate=`get_photo_date "${File}"`
	local PhotoTime=`get_photo_time "${File}"`
	case ${PhotoDate} in
		"unknown")
			# initialize by Unknown parameters
			PageNumLocal=${PageNumUnknown}
			INDEXCOUNTLocal=${INDEXCOUNTUnknown}
			;;
		*)
			# initialize by Date parameters
			PageNumLocal=${PageNumDate}
			INDEXCOUNTLocal=${INDEXCOUNTDate}
			;;
	esac

	# keep previous filename of image's page
	OldPage=${CurPage}

	# different date means new date
	if [ "${PhotoDate}" != "${CurDate}" ]; then
		PageNumLocal=0
		INDEXCOUNTLocal=0
		CurDate=${PhotoDate}
	fi

	# for next page
	if [ ${INDEXCOUNTLocal} -gt 0 -a "`expr ${INDEXCOUNTLocal} % ${Per}`" = 0 ]; then
		PageNumLocal=${INDEXCOUNTLocal}
	fi


	# initial CurPage
	CurPage=${IndexBase}_${PhotoDate}_`printf "%03d" ${PageNumLocal}`${IndexExt}
	while [ "${CurPage}" != "${OldPage}" -a -e ${CurPage} ]; do
		PageNumLocal=`expr ${PageNumLocal} + ${Per}`
		# next CurPage
		CurPage=${IndexBase}_${PhotoDate}_`printf "%03d" ${PageNumLocal}`${IndexExt}
	done

	# New Page

	if [ ! -e ${CurPage} ];then
		# for new page.
		body_each_index ${CurPage} >> ${TopPage}
		html_header > ${CurPage}

		if [ -e "${OldPage}" ];then
			html_footer >> ${OldPage}
		fi
	fi

	# Update Global Variables
	case ${PhotoDate} in
		"unknown")
			# initialize by Unknown parameters
			PageNumUnknown=${PageNumLocal}
			INDEXCOUNTUnknown=`expr ${INDEXCOUNTLocal} + 1`
			;;
		*)
			# initialize by Date parameters
			PageNumDate=${PageNumLocal}
			INDEXCOUNTDate=`expr ${INDEXCOUNTLocal} + 1`
			;;
	esac

	local FormattedFile="${File#${CWD}/}"
	echo ${FormattedFile} | grep -q '/'
	if [ $? -eq 0 -a ! -d ${ThumbDir}/${FormattedFile%/*} ]; then
		mkdir -p ${ThumbDir}/${FormattedFile%/*}
	fi
	local ThumbFile="${ThumbDir}/${FormattedFile%${AllExt}}_${XSize}${OutputImgExt}"

	# for before 0.9
	local ThumbFile09="${FormattedFile##*/}"
	ThumbFile09="${ThumbDir}/${ThumbFile09%${AllExt}}_${XSize}${OutputImgExt}"
	if [ -e "${ThumbFile09}" -a "${ThumbFile09}" != "${ThumbFile}" ]; then
		mv "${ThumbFile09}" "${ThumbFile}"
	fi

	if [ ${ThumbOnlyFlag} = 0 -a ! -e "${ThumbFile}" ]; then
		Messages "converting ${File}"
		${ConvertCmd} "${File}[0]" -scale ${XSize} "${ThumbFile}"
		if [ $? -ne 0 ]; then
			ThumbFile=${UNKNOWN_ICON}
		fi
	fi

	Messages "adding ${FormattedFile} to html(${CurPage})"
	html_body "${FormattedFile}" "${ThumbFile}" ${PhotoTime} >> ${CurPage}
	html_body "${FormattedFile}" "${ThumbFile}" "${PhotoDate}_${PhotoTime}" >> ${AllPhotoPage}

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

function RmHtml
{
	rm -f *.html
}

function MkHtml
{
	# Clean files
	RmHtml

	if [ ! -d ${ThumbDir} ]; then
		mkdir ${ThumbDir}
	fi

	html_header > ${TopPage}
	body_all_index >> ${TopPage}
	html_header > ${AllPhotoPage}

	local INDEXCOUNTDate=0
	local INDEXCOUNTUnknown=0
	# convert image files and add entry to index file

	find -L ${CWD} -name "${ThumbDir}" -prune -o -type f -print | egrep -i "(${SearchImgExt}|${SearchMovieExt})$" | sort \
	| while read File
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
ThisStructType="1.2"
FinishedStatus="Finished"
NotFullThumbnailStatus="Not Full Thumbnail"
FullThumbnailStatus="Full Thumbnail"

# Main Functions
function CheckMode
{
	for ARGV in $@;do 
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

	LogMessages "${CWD}"
	LogMessages "Status: ${ThisStatus}"
	LogMessages "StructType: ${FileStructType}"

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
			"-migrate"|"-m")
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
	if [ "${FileStatus}" = "${FinishedStatus}" ] && [ "${ThisStatus}" = "${FullThumbnailStatus}" ] \
			&& ( [ "${MigrateFlag}" != "1" ] || [ "${MigrateFlag}" = "1" -a "${FileStructType}" = "${ThisStructType}" ] ) ; then
		Messages "already finished : skipped."
		# Write Status
		echo "Status: ${FinishedStatus}" > ${StatusFile}
		echo "StructType: ${FileStructType}" >> ${StatusFile}
	else

		MkHtml

		# Write Status
		echo "Status: ${FinishedStatus}" > ${StatusFile}
		echo "StructType: ${ThisStructType}" >> ${StatusFile}
	fi

	return ${rc}
}

Mode $@

