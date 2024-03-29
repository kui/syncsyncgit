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
		* however, the version of apt repository git is 1.5.
		* install from [backports](http://backports-master.debian.org/Instructions/) or upgrade to Debian squeeze
	* CentOS 5.7

## How to Use

1. put syncsyncgit.sh on the directory contains `.git` directory.
2. execute `./syncsyncgit.sh start`.

### example

```sh
$ git clone git@github.com:kui/syncsyncgit.git
$ git clone <your_repository> <your_git_dir>
$ ln -s ${PWD}/syncsyncgit/syncsyncgit.sh <your_git_dir>/.syncsyncgit.sh
  or
$ mv ${PWD}/syncsyncgit/syncsyncgit.sh <your_git_dir>/.syncsyncgit.sh
$ cd <your_git_dir>
$ echo ".syncsyncgit.sh" >> .gitignore
$ ./.syncsyncgit.sh start
```
