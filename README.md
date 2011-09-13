# syncsyncgit.sh

using git repository as Dropbox.

basically just execute:

```sh
while true
do 
	git pull
	git add .
	git commit -a -m "$datetime"
	git push
	sleep $interval
done
```

## Tested Environment

* git 1.7
	* cannot work on git 1.5
* OS
	* Mac OS X 1.6
	* Debian lenny
	* CentOS 5.7

## How to Use

```sh
$ git clone git@github.com:kui/syncsyncgit.git
$ git clone <your_repository> <your_git_dir>
$ ln -s ${PWD}/syncsyncgit/syncsyncgit.sh <your_git_dir>/.syncsyncgit.sh
  or
$ mv ${PWD}/syncsyncgit/syncsyncgit.sh <your_git_dir>/.syncsyncgit.sh
$ <your_git_dir>/.syncsyncgit.sh start
```
