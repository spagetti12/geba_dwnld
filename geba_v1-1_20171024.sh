#set -x
#	0. BEFORE YOU START
#	go to http://wrdc.mgo.rssi.ru/ and log in:
#	user: pavle
#	password: pavle

# the script requires an argument or 2 arguments

#	1. DIFFUSE RADIATION:
#		sh geba.sh difrad

#	2. SUNSHINE DURATION:
#		sh geba.sh sundur

#	3. GLOBAL RADIATION:
#		--- REQUIRES 2 ARGUMENTS ---
#		parallel sh geba.sh ::: glbrad ::: $(seq 1 7)
#			this downloads all the global radiation files (takes too long)
#			if you want to download only one group of stations, run the script like this:
#				sh geba.sh glbrad 5 (eg for group of station #5)

#	depending on the argument(s), we define 3 'names', thats how they are named on wrdc website:
#		d - diffuse radiation
#		s - sunshine duration
#		t - global radiation

if [ "$1" = 'difrad' ]; then
name="d"
ct="44"
elif [ "$1" = 'sundur' ]; then
name="s"
ct="44"
elif [ "$1" = 'glbrad' ]; then
name="t""$2"
ct="45"
else echo 'no such variable'; exit
fi

#				START OF THE SCRIPT
#		make the working directory; temp dir (to be deleted later) and dir for daily data
mkdir "$1""$2"; cd "$1""$2"; mkdir temp; mkdir daily

curl -d "login=pavle" -d "password=pavle" http://wrdc.mgo.rssi.ru/wrdccgi/protect.exe?wrdc/wrdc_new.html

#		get the files from the GEBA website
wget --quiet -r -np -nH --cut-dirs=3 -R "$name".html http://wrdc.mgo.rssi.ru/wrdccgi/protect.exe?data_list_full_protected/"$name"/"$name".html

#		take the URLs from the downloaded files
find . -name "protect*" -type f | xargs grep http > down_"$name".log

#		delete the downloaded files
find . -name "protect.exe*" -type f | xargs rm

#		clean the URLs from downloaded files - remove everything before http
sed 's/^.*http/http/' down_"$name".log > temp1_"$name".log

#		remove everything after html
if [ "$1" = 'difrad' ] || [ "$1" = 'glbrad' ] ; then
sed 's/\".*//' temp1_"$name".log |grep _"$name".html > temp2_"$name".log
elif [ "$1" = 'sundur' ] ; then
sed 's/\".*//' temp1_"$name".log |grep .html > temp2_"$name".log
fi

curl -d "login=pavle" -d "password=pavle" http://wrdc.mgo.rssi.ru/wrdccgi/protect.exe?wrdc/wrdc_new.html
wget --quiet -i temp2_"$name".log

#		download the new cleaned URLs
if [ "$1" = 'sundur' ] ; then
find . -name "protect*" -type f | xargs grep http > down_take2_"$name".log
find . -name "protect.exe*" -type f | xargs rm
sed 's/^.*http/http/' down_take2_"$name".log > temp3_"$name".log
sed 's/\".*//' temp3_"$name".log |grep _"$name".html > temp4_"$name".log
curl -d "login=pavle" -d "password=pavle" http://wrdc.mgo.rssi.ru/wrdccgi/protect.exe?wrdc/wrdc_new.html
wget --quiet -i temp4_"$name".log
fi


#		rename the new files, there is now a name of station in the filename
for fn in protect.exe*; do newfn="$(echo "$fn" | cut -c"$ct"-)"; mv "$fn" "$newfn";done

#		replace %2F string from the filename with _
for i in ./*%2F*;do mv -- "$i" "${i//%2F/_}";done

#		convert the new files from html to txt
for i in ./*.html;do html2text "$i" > "$i".txt;done

#		change the extension of the new files from txt to html (this does not change the content)
if [ "$1" = 'sundur' ] ; then
for i in ./*_s.html.txt;do mv -- "$i" "${i//.html/}";done
else
for i in ./*.html.txt;do mv -- "$i" "${i//.html/}";done
fi

#		take only first 8 lines of the file with the station info (header)
#		take the only monthly mean values from each file
for i in *.txt;do head -8 "$i" > temp/"$i";grep -e Year -e DATE -e MEAN $i > zzzz_"$i";done

cd temp

#		HEADERS - remove the year in the end of every filename
#		this is done because all the headers for the same stations are the same, not depending on year

if [ "$1" = 'difrad' ] || [ "$1" = 'sunrad' ] ; then
ls *txt| awk -F. '{printf "mv %s %s\n",$0,substr($1,1,length($1)-7);}' |ksh
else ls *txt| awk -F. '{printf "mv %s %s\n",$0,substr($1,1,length($1)-8);}' |ksh
fi

#		join together headers with the values and change extension to csv
for file in *;do cat $file ../zzzz_"$file"* > ../"$file".csv;sed -i 's/_/ /g' ../"$file".csv;sed -i 's/|/ /g' ../"$file".csv;done
cd -

mv *txt daily

rm -rf temp *html *log

#		when the script is over, there will be folder named like the argument you've chosen
#		in this folder you'll find files with the montly data and folder daily with the daily data

#			written by Pavle Arsenovic January 2017
