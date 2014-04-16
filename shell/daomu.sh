#! /bin/bash

#
# 从daomubiji.com提取完整的小说
# 支持颜色，中断处理，断点续传
# Huntinux
# 2013-8-20
# v1.2
#


MAINURL="www.daomubiji.com"	# index.html's location
PWD=`pwd`
TMP="$PWD/tmp"			# temp dir
PAGESDIR="$TMP/pages"		# each chapter page's local location
NOVELDIR="$TMP/novel"		# each chapter
MAINPG="$TMP/index.html"	# index.html local location
URLS="$TMP/urls"		# contains all the pages' url
URLSINT="$TMP/urlsint"		# contains all the pages' url
SUFFIX=".txt"			# suffix of novel
INTFILE="$TMP/continue"

#
# 如果在下载过程中受到终止信号
# 不管是否下载完，都删除最后一个下载的网页
# 以保证网页能完整下载
# filename在down_extract()中定义
# 并且将中断处保存到文件INTFILE中，以便再次运行的时候能续传
#
trap '
	red "Interrupt occurred while downloading:$filename"
	red "Delete file: $PAGESDIR/$filename"
	red "Save interrupt point in $INTFILE"
	rm -f $PAGESDIR/$filename
	echo "$filename" >$INTFILE
	exit -1
' INT

#
# 彩色输出
#
NORMAL=$(tput sgr0)
GREEN=$(tput setaf 2; tput bold)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
function red() {
    echo -e "$RED$*$NORMAL"
}
 
function green() {
    echo -e "$GREEN$*$NORMAL"
}
 
function yellow() {
    echo -e "$YELLOW$*$NORMAL"
}


# 从下载的网页中提取小说内容
# 参数0表示要提取内容的网页
extract_page(){ 
	green "Extract page $1"

	# 得到章节名称
	# title=`grep "<h1>" $1 | sed -e "s=^.*<h1>==" -e "s=</h1>==" | tr ' ' '_'`
	# 上面的写法有问题，貌似最后有一个回车
	title=`grep "<h1>" $1 | cut -d'>' -f2 | cut -d'<' -f1 | tr ' ' '_'`
	title=$title$SUFFIX

	# 得到卷名
	chapter=` echo $title | cut -d'_' -f1`
	green "Title : $title -->Chapter : $chapter"

	# 创建卷目录
	if [ ! -d  $NOVELDIR/$chapter ];then
		mkdir -p $NOVELDIR/$chapter
	else
		yellow "Directory $chapter exists."
	fi

	# 提取小说内容保存在相应卷目录
	filepath=$NOVELDIR/$chapter/$title  
	if [ ! -e $filepath ]; then
		cat $1 | sed '/精彩评论/,$d' \
			| grep -E "<p>　　|<h1>" \
				| sed 's=<span[^<]*</span==g'  \
					| tr "<p>/h1" "      ">$filepath
	else
		yellow "File $title exists"
	fi
	green "Done."
}

# 下载每个页面，并调用extract_page来提取小说内容
down_extract(){
	# 检测是否需要断点续传
	if [ -e $INTFILE ]; then
		red "Detect a interrupt, and continue..."
		intpoint=`cat $INTFILE` # 得到中断时，正在下载的网页名称
		red "Continue downloading ：$intpoint"
		echo $MAINURL/$intpoint >$URLSINT # 因为中断的时候最后一个被删除，所以把它放到第一个，继续下载
		sed '1,/'"$intpoint"'/d' $URLS >>$URLSINT # 然后找到它后面的网址，也加入URLSINT文件
		#rm -f $URLS	# 删除原来的urls文件
		URLS=$URLSINT   # 修改URLS变量指向新的urlsint文件
	fi

	# for i in `cat $URLS | xargs`	# 使用xargs以防止参数过大。有必要吗？
	for i in `cat $URLS`	
	do
		filename=`basename $i`
		if [ ! -e $PAGESDIR/$filename ]; then
			green "Downloading page :$i"
			wget -P $PAGESDIR $i 1>/dev/null 2>/dev/null
			green "Done."
		else
			yellow "$filename already exists."
		fi
		extract_page $PAGESDIR/$filename
	done

	red "Finished."
}

# 得到含有所以章节连接的网页
get_index(){
	if [ ! -e $MAINPG ]; then
		# wget -P $TMP $MAINURL # 1>/dev/null 2>/dev/null  -P 用来指定下载目录
		green "Downloading $MAINURL/index.html"
		wget -P $TMP $MAINURL  1>/dev/null 2>/dev/null 
		green "Done."
	else
		yellow "index.html already exists."
	fi
}

# 得到主页上的所以章节的链接地址
parse_index(){
	# 应为网页上的链接有可能更新，而且生成所有的url的时间也不长
	# 所以没有再判断urls文件是否存在

	sed -e '1,/盗墓笔记-南派三叔经典巨作/d' \
		-e  '/最新发布/,$d' $MAINPG \
			| grep "href"  \
				| cut -d"\"" -f2 >$URLS
	green "Get all urls in $URLS"
}


# 
# 程序开始
#

# 创建临时目录
if [ ! -d $TMP ]; then
	green  "Creat temporary directory:$TMP,$PAGESDIR,$NOVELDIR"
	mkdir -p $TMP/{pages,novel} || {
		red  "Error while creating temporary directory:$TMP,$PAGESDIR,$NOVELDIR"
		exit -1
	}
else
	yellow "Directory $TMP exists."
fi 


# 获取index.html
get_index
# 解析index.html
parse_index
# 下载页面，并提取小说内容
down_extract


exit 0
