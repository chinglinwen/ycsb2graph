#!/bin/sh
#==============================================================
# DESCRIPTION: Generate graph for ycsb testing results
#              
#        FILE: ycsb2graph.sh
#       USAGE: ./ycsb2graph.sh [result-directories...]
#      AUTHOR: Wen Zhenglin
#        DATE: 2016-8-16
#     VERSION: 1.0
#
# Revision history:
# 1.0		(2016-8-16)Created. 
#==============================================================

# For one result directory or multiple result directory
# It can be single db result per directory, or mix for multiple db result
# It can even combine the old result
# So in order to do comparison, you only just do one more test for that db

resultDir=( $@ )
if [ "x$resultDir" = "x" ]; then
  resultDir="."
fi
if [ ${#resultDir[@]} -gt 1 ]; then
  pageDir="$( dirname $resultDir )"
else
  pageDir="$resultDir"
fi
echo "Use the results directory: ${resultDir[@]}"

# check at least one result file exist
results="$( find ${resultDir[@]} -name '*.result' )"
if [ "x$results" = "x" ]; then
  echo "Result file is not found"
  exit 1
fi

types="$( echo "$results" | awk '{ print $NF }' FS='/' | \
               awk '{ print $2 }' FS='-' | sort | uniq )"
cnt="$( echo $types | wc -l )"
if [ $cnt -eq 0 ]; then
  echo "No any workloads results be found"
  exit 1
fi
#append op-count to to the filename
#dbname-WorkloadA-100.result

getAvg () {
  #unit Nonoseconds
  grep Average
}

noNaN () {
  getAvg | grep -v NaN
}

getOps () {
  #unit count
  grep Operations
}

getRunTime () {
  xargs grep -H 'RunTime'
}

getThroughput () {
  xargs grep -H 'Throughput'
}


# uniq and compare, use the max count one
# it often just the same

getCategory () {
  cate=""
  contents="$( cat | awk '{ print $NF }' FS='/'  | \
                 awk '{ print $1 }' FS='.result' | \
		           awk '{ print $3 }' FS='-' | sort -n | uniq )"
  
  while read l; do
    if [ "x$l" = "x" ]; then
      continue
    fi
    if [ "x$cate" = "x" ]; then
      cate="'$l'"
    else
      cate="$cate,'$l'"
    fi
  done <<eof
$contents
eof
  echo "$cate"
}

getData () {
  contents="$1"
  
  data=""
  while read l; do
    if [ "x$l" = "x" ]; then
      continue
    fi
    
    j="$( echo $l | awk '{ print $3 }' )"
    
    echo "$l" | grep -e Throughput -e FAILED > /dev/null
    if [ $? -ne 0 ]; then
      # convert to milliseconds
      # for runtime, it is to seconds
      j="$( awk "BEGIN {printf \"%.3f\", $j/1000}" )"
    fi
    
    if [ "x$data" = "x" ]; then
      data="$j"
    else
      data="$data,$j"
    fi
  done <<eof
$contents
eof
  echo "$data"
}

getSubtitle () {
  k="$1"
  subtitle=""
  case "$k" in
    WorkloadA) subtitle="Update heavy, Read/Update ratio: 50/50" ;;
    WorkloadB) subtitle="Read mostly, Read/Update ratio: 95/5" ;;
    WorkloadC) subtitle="Read only, Read/Update ratio: 100/0" ;;
    WorkloadD) subtitle="Read latest, Read/Update/Insert ratio: 95/0/5" ;;
    WorkloadE) subtitle="Short ranges scan, Scan/Insert ratio: 95/5" ;;
    WorkloadF) subtitle="Read-Modify-Write, Read/Read-Modify-Write ratio: 50/50" ;;
    *) subtitle="Unknown workload name" ;;
  esac
  echo "$subtitle"
}

genGraph () {
  id="$1"
  dbs="$2"
  output="$3"
  
  symbols=( circle square diamond triangle triangle-down )
  
  allseries=""
  
  i=0
  while read db; do
    if [ "x$db" = "x" ]; then
      continue
    fi
    contents="$( echo "$output" | grep -w "$db" )"
    data="$( getData "$contents" )"
    if [ "x$data" != "x" ]; then
      name="$db"
      symbol="${symbols[i]}"
      . ./series.template
    fi
    (( i++ ))
  done <<eof
$dbs
eof
  
  k="$( echo $id | awk '{ print $1 }' FS='-' )"
  desc="$( echo $id | sed "s/$k-//" )"
  title="$k $desc"
  subtitle="$( getSubtitle "$k" )"
  ytitle="Latency (Milliseconds)"
  xtitle="Throughput"
  
  echo "$desc" | grep FAILED >/dev/null
  if [ $? -eq 0 ]; then
    ytitle="Operations"
  fi
  
  if [ "$desc" = "OVERALL-RunTime" ]; then
    ytitle="RunTime (Seconds)"
  fi
  
  if [ "$desc" = "OVERALL-Throughput" ]; then
    ytitle="Throughput (ops/sec)"
  fi
  
  . ./graph.template
  headline=""
}

analyze () {
  type="$1"
  files="$2"
  
  category="$( echo "$files" | getCategory )"
 
  dbs="$( echo "$files" | awk '{ print $NF }' FS='/' | \
              awk '{ print $1 }' FS='-' | uniq )"
  out=""
  headline="<h2>$type</h2>"
  
  opkind="$( echo "$files" | xargs grep '^\[' | grep -v -e TOTAL \
              -e CLEANUP -e OVERALL | awk '{ print $1 }' FS=',' | \
              awk '{ print $2 }' FS=':' | \
              sort -d | uniq )"
  
  while read op; do
    key="$( echo $op | sed 's/\[/\\[/' )"
    opname="$( echo $op | tr -d '[]' )"
    out="$( echo "$files" | xargs grep "$key" | noNaN )"
    
    color=""
    echo "$op" | grep FAILED > /dev/null
    if [ $? -eq 0 ]; then
      color="color: '#FF9800'"
      out="$( echo "$files" | xargs grep "$key" | getOps )"
    fi
    
    if [ "x$out" != "x" ]; then
      genGraph "$type-$opname" "$dbs" "$out"
    fi
  done<<eof
$opkind
eof

  color=""
  out="$( echo "$files" | getRunTime )"
  if [ "x$out" != "x" ]; then
    genGraph "$type-OVERALL-RunTime" "$dbs" "$out"
  fi

  out="$( echo "$files" | getThroughput )"
  if [ "x$out" != "x" ]; then
    genGraph "$type-OVERALL-Throughput" "$dbs" "$out"
  fi
}

while read type; do
  echo "start $type"
  files="$( echo "$results" | grep "$type" | sort -V )"
  analyze "$type" "$files"
done <<eof
$types
eof

. ./page.template
echo "$page" > "$pageDir/index.html"

echo "see the url: http://192.168.100.94:8000/$pageDir"
#end.
