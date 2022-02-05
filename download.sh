#!/bin/bash

# config
url="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
project="google-chrome-linux"
list_file="README.md"
# /config

_exit()
{
	local exit_code="$1"
	
	rm $tmp $headers $fields 2>/dev/null
	
	exit $exit_code
}

tmp="${project}.output.$$.tmp"
headers="${project}.headers.$$.tmp"
fields="${project}.fields.$$.tmp"

now2=`TZ=UTC date '+%s'`
now=`TZ=UTC date '+%Y-%m-%d %H:%M:%S %:z' --date "@${now2}"`

echo "Downloading ${url} to ${tmp}"

curl -s -L -D $headers -o $tmp $url \
  -H 'authority: dl.google.com' \
  -H 'sec-ch-ua: " Not;A Brand";v="99", "Google Chrome";v="97", "Chromium";v="97"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Linux"' \
  -H 'upgrade-insecure-requests: 1' \
  -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.99 Safari/537.36' \
  -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'sec-fetch-site: none' \
  -H 'sec-fetch-mode: navigate' \
  -H 'sec-fetch-user: ?1' \
  -H 'sec-fetch-dest: document' \
  -H 'accept-language: en-US,en;q=0.9'

result=$?

if [ $result != 0 ]; then
	echo "ERROR: download failed."
	_exit 1
fi

echo "Download finished. Extracting and processing Debian controlfile fields..."

dpkg-deb --field $tmp > $fields

size=`stat --format %s $tmp`

a=`cat $fields | grep -Ei '^package: ' | cut -d ' ' -f 2- | head -n 1`
b=`cat $fields | grep -Ei '^architecture: ' | cut -d ' ' -f 2- | head -n 1`
c=`cat $fields | grep -Ei '^version: ' | cut -d ' ' -f 2- | head -n 1`
d=`cat $fields | grep -Ei '^installed-size: ' | cut -d ' ' -f 2- | head -n 1`

checksum_md5=`cat $tmp | md5sum | awk '{ print $1; }'`
checksum_sha1=`cat $tmp | sha1sum | awk '{ print $1; }'`
checksum_sha256=`cat $tmp | sha256sum | awk '{ print $1; }'`

if echo "$c" | grep -Eq '[-+._0-9a-zA-Z]+'; then
	version="${c}"
else
	version="unknown"
fi

if echo "$b" | grep -Eq '[-+._0-9a-zA-Z]+'; then
	arch="${b}"
else
	arch="unknown"
fi

final_filename="${project}_${version}_${arch}_${now2}.deb"

line="| $size | $a | $b | $c | $d | $checksum_md5 | $checksum_sha1 | $checksum_sha256 |"

echo "Details: $line"

if cat $list_file | grep -q "${line}"; then
	echo "This release was already added, skipping and exiting."
	_exit 0
fi

echo "This is a new release, adding to the repository..."

echo "| $final_filename | $now $line" >> $list_file

mv $tmp $final_filename

git add $final_filename $list_file

git commit -m "Added ${final_filename}"

git push

echo "All done."

_exit 0
