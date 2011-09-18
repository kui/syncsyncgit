#!/bin/sh
#
#  using a git repository as Dropbox
#

SETTING_FILE="etc/syncsyncgit/syncsyncgit.config"

main(){

    cd `dirname $0`

    init

    #PID_FILE=`get_pid_file_name`
    #LOG_FILE=`get_log_file_name`
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
    set_echo
    read_setting_file
}

set_echo(){
    echo="`which echo`"
    test -e "$echo"  || echo="echo"
}

read_setting_file(){

    source $SETTING_FILE || exit 1

    # checking params
    for param in interval default_repository default_branch\
                 pid_file log_file gc_interval target_list_files
    do
        if eval '[ -z $'"$param"' ]'
        then
            $echo "cannot found '$param' parameter" >&2
            exit 1
        fi
    done

    INTERVAL=$interval
    DEFAULT_REPOSITORY=$default_repository
    DEFAULT_BRANCH=$default_branch
    PID_FILE=$pid_file
    LOG_FILE=$log_file
    GC_INTERVAL=$gc_interval
    TARGET_FILES=()
    for list_file in "${target_list_files[@]}"
    do
        for file_and_repo in `cat $list_file|sed -e s/ +/\\\ /g`
        do
            file="`get_file_repo_branch $file_and_repo`"
            TARGET_FILES=("${TARGET_FILES[@]}" "$file")
            echo ${TARGET_FILES[@]}
        done # 2> /dev/null
    done
    
    for param in INTERVAL DEFAULT_REPOSITORY DEFAULT_BRANCH PID_FILE LOG_FILE\
                 GC_INTERVAL
    do
        eval $echo '$param:	$'"$param"
    done
    echo "TARGET_FILES: ${TARGET_FILES[@]}"
}

get_file_repo_branch(){
    if [ $1 ] ;then $echo $1; else return 1; fi
    if [ $2 ] ;then $echo $2; else $echo $DEFAULT_REPOSITORY; fi
    if [ $3 ] ;then $echo $3; else $echo $DEFAULT_BRANCH; fi
}

echo_array(){
    for el in "$@"
    do
        $echo -n "$el, "
    done
    $echo
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
	sync_all | logger
	if [ $count -gt $GC_INTERVAL ]
	then
	    git gc 2>&1 | logger
	    # echo "git gc" | logger
	    count=0
	fi
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
    $echo "# sync"
    sync_all
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

sync_all(){

    for target in "${TARGET_FILES[@]}"
    do
        sync target
    done

}

sync(){

    cd $1

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
