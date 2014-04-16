#! /bin/bash

#
# 从daomubiji.com提取完整的小说
# v0.1
# huntinux@gmail.com
# chj90220@126.com
# 

MAINURL="www.daomubiji.com"	# index.html's location
PWD=`pwd`
TMP="$PWD/tmp"				# temp dir
PAGESDIR="$TMP/pages"		# each chapter page's local location
NOVELDIR="$TMP/novel"		# each chapter
MAINPG="$TMP/index.html"	# index.html local location
URLS="$TMP/urls"			# contains all the pages' url
SUFFIX=".txt"				# suffix of novel


# 从下载的网页中提取小说内容
# 参数0表示要提取内容的网页
extract_page(){ 
	echo "extract page $1"

	# 得到章节名称
	title=`grep "<h1>" $1 | cut -d'>' -f2 | cut -d'<' -f1 | tr ' ' '_'`
	title=$title$SUFFIX

	# 得到卷名
	chapter=` echo $title | cut -d'_' -f1`
	echo -e "title = $title\nchapter = $chapter"

	# 创建卷目录
	if [ ! -d  $NOVELDIR/$chapter ];then
		mkdir -p $NOVELDIR/$chapter
	else
		echo "directory $chapter exists."
	fi

	# 提取小说内容保存在相应卷目录
	filepath=$NOVELDIR/$chapter/$title  
	if [ ! -e $filepath ]; then
		cat $1 | sed '/精彩评论/,$d' \
			| grep -E "<p>　　|<h1>" \
				| sed 's=<span[^<]*</span==g'  \
					| tr "<p>/h1" "      ">$filepath
	else
		echo "file $title exists"
	fi

}

# 下载每个页面，并调用extract_page来提取小说内容
down_extract(){

	# for i in `cat $URLS | xargs`	# 使用xargs以防止参数过大。有必要吗？
	for i in `cat $URLS`	
	do
		filename=`basename $i`
		if [ ! -e $PAGESDIR/$filename ]; then
			wget -P $PAGESDIR $i
		else
			echo "$filename already exists."
		fi
		extract_page $PAGESDIR/$filename
	done
}

# 得到含有所有章节链接的网页
get_index(){
	if [ ! -e $MAINPG ]; then
		# wget -P $TMP $MAINURL # 1>/dev/null 2>/dev/null  -P 用来指定下载目录
		wget -P $TMP $MAINURL # 1>/dev/null 2>/dev/null 
	else
		echo "index.html already exists."
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
	echo "Get all urls in $URLS"
}


# 
# start
#

# 创建临时目录
if [ ! -d $TMP ]; then
	echo -e "Creat temporary directory: \
		\n$TMP\n$PAGESDIR\n$NOVELDIR"
	mkdir -p $TMP/{pages,novel} || {
		echo -e "Error while creating temporary directory: \
			\n$TMP\n$PAGESDIR\n$NOVELDIR"
		exit -1
	}
else
	echo "Directory $TMP exists."
fi 


# 获取index.html
get_index
# 解析index.html
parse_index
# 下载页面，并提取小说内容
down_extract


exit 0
