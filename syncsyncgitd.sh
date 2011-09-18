#!/bin/sh
#
#  using a git repository as Dropbox
#

##################### User Settings ########################
#  if this script find $SETTING_FILES (see below), 
# these settings in here will be ignored.

# sync interval [sec]
INTERVAL=60

# target repository
REPOSITORY="origin"

# target branch
BRANCH="master"
#################### /User Settings ########################

SETTING_FILE=".syncsyncgit.settings"
LOG_DIR="$HOME/local/var/log"
PID_DIR="$HOME/local/var/run"

GC_INTERVAL=20

main(){

    cd `dirname $0`

    init 

    PID_FILE=`get_pid_file_name`
    LOG_FILE=`get_log_file_name`
    case $1 in
        start) run ;;
        stop) stop ;;
        restart) restart ;;
        sync) sync_once ;;
        log) cat_log ;;
        *) help;;
    esac

}

init(){
    echo="`which echo`"
    test -e "$echo"  || echo="echo"
    read_setting_file
}

read_setting_file(){
    if ! [ -e "$SETTING_FILE" ] 
    then
        return 0
    fi
    eval "`cat \"$SETTING_FILE\"`"
}

run(){

    if ! is_git_dir
    then
	$echo "the current dir is not a git ripository" >&2
	exit 1
    fi

    is_already_started

    count=0
    check_dir "$LOG_FILE"

    $echo -n "start: "

    $echo "start sync" | logger
    while true
    do
	sync | logger
	if [ $count -gt $GC_INTERVAL ]
	then
	    git gc 2>&1 | logger
	    # echo "git gc" | logger
	    count=0
	fi
        to_be_or_not_to_be | logger
	sleep $INTERVAL
	count=$[$count+1]
    done &

    pid=$!

    if [ $? -eq 0 ]
    then
	$echo "OK"
	create_pid_file $pid
    else
	$echo "FALSE"
	exit 1
    fi

}

stop(){
    local pid=`get_pid`
    local retry_count=30

    if ! exist_pid $pid
    then
	$echo "error: Not started" >&2
	exit 1
    fi

    $echo -n "stop: "
    while [ $retry_count -gt 0 ]
    do
	kill -2 $pid
	sleep 0.03
	if ! exist_pid $pid
	then
	    break
	fi
	local retry_count=$(($retry_count-1))
    done

    if [ $retry_count -eq 0 ] && (! kill -9 $pid)
    then
	$echo "FALSE"
	exit 1
    fi

    $echo "OK"
    create_pid_file $!

    delete_pid_file
}

restart(){
    stop && run
}

sync_once(){
    $echo "# sync with $REPOSITORY $BRANCH"
    sync
}

cat_log(){
    cat "$LOG_FILE"
}

exist_pid(){
    local pid=$1
    [ -n "$pid" ] && [ -n "`ps -p $pid -o comm=`" ]
}

is_git_dir(){
    git status > /dev/null 2>&1
}

logger(){
    local datetime=`date +'%F %T'`
    sed -e "s/^/$datetime /" >> "$LOG_FILE"
}

sigint_hook(){
    $echo 
    $echo "exit $0"
    exit 0
}

is_already_started(){
    local pid=`get_pid`
    if exist_pid $pid
    then
	$echo "error: Already started (pid:$pid)" >&2
	exit 1
    fi
}

create_pid_file(){
    # local pid_file=`get_pid_file_name`
    check_dir "$PID_FILE"
    $echo "$1"  > "$PID_FILE"
}

get_pid(){
    # local pid_file=`get_pid_file_name`
    cat "$PID_FILE" 2> /dev/null
}

delete_pid_file(){
    # local pid_file=`get_pid_file_name`
    rm "$PID_FILE"
}

get_log_file_name(){
    get_file_name $LOG_DIR "log"
}

get_pid_file_name(){
    get_file_name $PID_DIR "pid"
}

get_file_name(){
    local dir=$1
    local suffix=$2
    if ! $echo $dir | grep "/$" > /dev/null 2>&1
    then
	local dir="$dir/"
    fi
    $echo "$dir`get_base_file_name`.$suffix"
}

get_base_file_name(){
    pwd | sed -e 's/[\\.\\/]/_/g' |\
      sed -e 's/$/_syncsyncgit/'
}

have_tty(){
    local pid=`get_pid`
    local tty=`ps h -o tt= -p $pid`
    echo "$tty" | grep -v '?' > /dev/null
}

to_be_or_not_to_be(){
    if ! have_tty
    then
        stop
    fi
}

check_dir(){
    local file=$1
    local dir=`dirname "$file"`
    if ! [ -d "$dir" ]
    then
	local cmd="mkdir -p \"$dir\""
	$echo $cmd
	eval $cmd
    fi
}

sync(){

    if [ -z $BRANCH ] || [ -z $REPOSITORY ]
    then
        $echo "error: set $BRANCH and $REPOSITORY" >&2
        exit 1
    fi

    git pull --ff --quiet "$REPOSITORY" "$BRANCH" 2>&1
    git add . 2>&1
    local dry_run=`commit --porcelain 2>&1`
    if [ -n "$dry_run" ]
    then
	$echo "$dry_run"
	commit --quiet
    fi
    git push --quiet "$REPOSITORY" "$BRANCH" 2>&1 |\
      grep -v "^Everything up-to-date$"
}

commit(){
    local options="$@"
    git commit $options --all --message "`date +'%F %T'` $0" 2>&1 |\
      grep -v "^# On branch master$" |\
      grep -v "^nothing to commit (working directory clean)$"
}

help(){
    $echo "\
$0 {start|stop|sync|log}
  start: start sync
  stop: stop sync
  sync: do sync just one time
  log: show log
"
}
 
main "$@"
