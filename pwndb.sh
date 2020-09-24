#!/usr/bin/bash

#stty -echoctl

trap '[[ `ls $tmp/res/` ]] && cat  $tmp/res/* | sort > $output; rm -rf $tmp' EXIT

tmp=$(mktemp -d --tmpdir=.)
mkdir $tmp/req $tmp/res
proxy="127.0.0.1:9050"
exact=1
exactdom=1
wild="%"
output=$(date +%d-%m-%d_%H-%M.txt)
jobs=5

usage(){
  echo -e """pwndb.sh

usage:
-u|--user [USER]          user to check
-U|--user-list [FILE]     file containing users (1 per line)
-e|--exact                check exact user
-d|--domain [DOMAIN]      domain
-D|--domain-list [FILE]   file containing domains (1 per line)
-b|--brute-force [NUMBER] brute force   1 will be A to Z ,
                                        2 will be AA to ZZ
-j|--jobs [number]        number of background jobs (default 5)
-p|--password [PASSWORD]  search email from password
-P|--pasword-list [FILE]  file containing password (1 per line)
-o|--output [file]        output file
-x|--proxy [IP:PORT]      proxy and port of TOR

whildecard character is "%"

exemples:
pwndb -u crime -e -d gmail.com -o result.txt
pwndb -U user.lst -D domain.lst -x 127.0.0.1:9999
pwndb -b 2 -d gmail.com -o result.txt
pwndb -b 4 -j 10 -d "%.gouv.fr" 
pwnd -p fuckthepopo -j 10 -o res.lst -x 192.168.75.225:9050 
"""
}


if [[ ${#@} > 0 ]]; then
  while [ "$1" != "" ]; do
    case $1 in
      -u | --user )
        shift
        cmd="echo \"$1\""
        ;;
      -U | -user-list)
        shift
        cmd="cat $1"
        ;;
      -e | --exact-user)
        exact=0
        wild=""
        ;;
      -E | --exact-domain)
        exactdom=0
        ;;
      -d | --domain )
        shift
        domain=true
        cmddom="echo $1"
        ;;
      -D|--domain-list)
        shift
        domain=true
        cmddom="cat $1"
        ;;
      -b | --brute-force)
        shift
        list=true
        iterate_nbr=$(eval printf '\{a..z\}%.0s' {1..$1})
        cmd="printf '%s\\n' $iterate_nbr"
        ;;
      -p|--password)
        shift
        passwd=true
        cmd="echo $1"
        ;;
      -P|--password-list)
        shift
        passwd=true
        cmd="cat $1"
        ;;
      -j|--jobs)
        shift
        [[ "$1" > 10 ]] && echo "cant use more than 10 jobs" && sleep 1 && usage && exit 1
        jobs="$1"
        ;;
      -o|--output)
        shift
        output="$1"
        ;;
      -x|--proxy)
        shift
        proxy="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        exit 1
        ;;
    esac
    shift
  done
else
  usage
  exit 1
fi


[[ $domain == true ]] && [[ $passwd == true ]] && echo "Cant search password and domain at the same time" && exit 1
[[ -z $cmd ]] && cmd="echo %" && wild=''
passwd(){
    echo -ne "\r\e[0K\e[0m[`date -u -d @${SECONDS} +"%T"`]--→[$1]"
  until [[ $(curl  -sk -o "$tmp/req/$1.txt" -w "%{http_code}" --socks5-hostname $proxy -d "password=$1&submitform=pw"  pwndb2am4tzkvold.onion) == 200 ]] ; do 
    echo -ne "\r\e[0KProblem occurs... restart $line"
    sleep 3 
  done
  while IFS= read -r line; do
    if grep -E "^(" <<<"$line" 2>/dev/null; then user="" && domain="" && pass="" ; fi
    if grep '\[luser\] =' <<<"$line" >/dev/null; then user="$(cut -d ' ' -f7 <<<"$line")"; fi
    if grep '\[domain\] =' <<<"$line" >/dev/null ; then domain="$(cut -d ' ' -f7 <<<"$line")"; fi
    if grep '\[password\] =' <<<"$line" >/dev/null ; then pass="$(cut -d ' ' -f7 <<<"$line")"; fi
    [[ $line == ")" ]] && [[ -n $user ]] && echo -ne "\r\e[31m[\e[37m$1\e[31m]--→[\e[33m$user\e[0m@\e[37m$domain\e[0m:\e[36m$pass\e[31m]\n" && echo "$user@$domain:$pass" >> "$tmp/res/$1.txt"  
  done < <(eval pup pre < $tmp/req/$1.txt | sed '1,11d;$d')
}


req_n_parse(){
  echo -ne "\r\e[0K\e[0m[`date -u -d @${SECONDS} +"%T"`]--→[$1]"
  until [[ $(curl  -sk -o "$tmp/req/$1.txt" -w "%{http_code}" --socks5-hostname $proxy -d "luser=$1$2&domain=$3&luseropr=$4&domainopr=1&submitform=em"  pwndb2am4tzkvold.onion) == 200 ]] ; do 
    echo -ne "\r\e[0KProblem occurs... restart $line"
    sleep 3 
  done
  while IFS= read -r line; do
    if grep -E "^(" <<<"$line" 2>/dev/null; then user="" && domain="" && pass="" ; fi
    if grep '\[luser\] =' <<<"$line" >/dev/null; then user="$(cut -d ' ' -f7 <<<"$line")"; fi
    if grep '\[domain\] =' <<<"$line" >/dev/null ; then domain="$(cut -d ' ' -f7 <<<"$line")"; fi
    if grep '\[password\] =' <<<"$line" >/dev/null ; then pass="$(cut -d ' ' -f7 <<<"$line")"; fi
    [[ $line == ")" ]] && [[ -n $user ]] && echo -ne "\r\e[31m[\e[37m$1\e[31m]--→[\e[33m$user\e[0m@\e[37m$domain\e[0m:\e[36m$pass\e[31m]\n" && echo "$user@$domain:$pass" >> "$tmp/res/$1.txt"  
  done < <(eval pup pre < $tmp/req/$1.txt | sed '1,11d;$d')
  rm $tmp/req/$1.txt
}


pwait(){
  while [ $(jobs -p | wc -l) -ge $1 ]; do
    sleep 1
  done
}


if [[ $passwd == true ]]; then
  while IFS= read -r passd; do
    passwd $passd &
    pwait $jobs
  done < <(eval $cmd)
  wait
  exit
fi

while IFS= read -r dom; do
  while IFS= read -r line; do
    req_n_parse "$line" "$wild" "$dom" $exact & 
    pwait $jobs
  done < <(eval $cmd)
done < <(eval $cmddom)
wait

echo -e "\n\nDuration: `date -u -d @${SECONDS} +"%T"`"