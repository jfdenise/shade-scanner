#!/bin/sh

if [ ! -n "${1}" ]; then
  echo "A path to a jar must be provided"
  exit 1
fi
jarFile="$1"
if [ ! -f "${jarFile}" ]; then
 echo "The file ${jarFile} doesn't exist"
 exit 1
fi

rm -rf shade-scanner-output
mkdir -p shade-scanner-output
echo "Scanned JAR is unzipped in shade-scanner-output directory."
jarFileName=$(basename "${jarFile}")
mkdir -p "shade-scanner-output/${jarFileName}"
unzip "${jarFile}" -d "shade-scanner-output/${jarFileName}" 2>&1 > /dev/null
if [ -d "shade-scanner-output/${jarFileName}/META-INF/maven" ]; then
 array=()
 pomFiles=$(find shade-scanner-output/${jarFileName}/META-INF/maven -name pom.xml)
 readarray pomsArray <<< "${pomFiles}"
 len=${#pomsArray[@]}
 if [ "$len" != "1" ]; then
  echo "$jarFileName shades " $(($len - 1)) " artifacts"
  for p in "${pomsArray[@]}"; do
    p=$(echo $p|tr -d '\n')
    dir=$(dirname $p)
    props=$dir/pom.properties
    version=`cat $props | grep "version" | cut -d'=' -f2`
    x="${p#*shade-scanner-output/${jarFileName}/META-INF/maven/}"
    x=$(dirname $x)
    artifactId=$(basename $x)
    if [[ "$jarFileName" != "$artifactId-"* ]]; then
      x=${x////:}
      array+=("$x:$version")
    fi
  done
  sorted=($(for a in "${array[@]}"; do echo "$a"; done | sort))
  for dep in "${sorted[@]}"; do echo "  $dep"; done
 fi
else
 echo "The jar $jarFileName doesn't contain Maven metadata, can't identofy shaded dependencies."
fi
