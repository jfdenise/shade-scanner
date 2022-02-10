#!/bin/sh

jbossHome="."
if [ -n "${1}" ]; then
  jbossHome="${1}"
fi
if [ ! -d "${jbossHome}/modules" ] && [ ! -f "${jbossHome}/jboss-modules.jar" ]; then
  echo "ERROR, Not a valid server installation"
  exit 1
fi
rm -rf shade-scanner-output
mkdir -p shade-scanner-output
echo "Scanned JARS are unzipped in shade-scanner-output directory."
FILES=$(find ${jbossHome}/modules/ -name \*.jar)
readarray ARR <<< "${FILES}"
notMaven=
allJars=
allShadedJarsNoVersion=
declare -A hashmap
declare -A modulesMap
for i in "${ARR[@]}"; do
 jarFileName=$(basename "${i}")

 if [ ! -d "shade-scanner-output/${jarFileName}" ]; then
   mkdir -p "shade-scanner-output/${jarFileName}"
   unzip $i -d "shade-scanner-output/${jarFileName}" 2>&1 > /dev/null
   if [ -d "shade-scanner-output/${jarFileName}/META-INF/maven" ]; then
     modulesMap["$jarFileName"]="$(echo $i|tr -d '\n')"
     allJars="$allJars $jarFileName"
     pomFiles=$(find shade-scanner-output/${jarFileName}/META-INF/maven -name pom.xml)
     readarray pomsArray <<< "${pomFiles}"
     len=${#pomsArray[@]}
     if [ "$len" != "1" ]; then
      echo "$i shades " $(($len - 1)) " artifacts"
      array=()
      for p in "${pomsArray[@]}"; do
        p=$(echo $p|tr -d '\n')
        dir=$(dirname $p)
        props=$dir/pom.properties
        version=`cat $props | grep "version" | cut -d'=' -f2`
        x="${p#*shade-scanner-output/${jarFileName}/META-INF/maven/}"
        x=$(dirname $x)
        artifactId=$(basename $x)
        if [[ "$jarFileName" != "$artifactId-"* ]]; then
          allShadedJarsNoVersion="$allShadedJarsNoVersion $artifactId-"
          x=${x////:}
          hashmap["$artifactId-"]="$i[$x:$version]"
          array+=("$x:$version")
        fi
      done
      sorted=($(for a in "${array[@]}"; do echo "$a"; done | sort))
      for dep in "${sorted[@]}"; do echo "  $dep"; done
     fi
   else
     notMaven="$notMaven$i"
   fi
 fi
done

# Check for duplicates
# A shaded JAR being a module artifact possibly with different version
read -r -a ALLSHADEDNOVERSION <<< "${allShadedJarsNoVersion}"
read -r -a ALLJARS <<< "${allJars}"
  for i in "${ALLJARS[@]}"; do
      for j in "${ALLSHADEDNOVERSION[@]}"; do
        if [[ "$i" == $j*".jar" ]]; then
          echo "WARNING: ${modulesMap[$i]} is shaded in:" ${hashmap[$j]}
        fi
      done
  done

#echo "Jars that don't contain Maven metadata:"
#echo "$notMaven"

