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
