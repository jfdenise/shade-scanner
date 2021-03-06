#!/bin/sh
 source ./common.sh

jbossHome="${1}"
if [ ! -n "${1}" ]; then
  echo "A path to a server installation must be provided"
  exit 1
fi
jbossHome="${1}"
if [ ! -d "${jbossHome}/modules" ] && [ ! -f "${jbossHome}/jboss-modules.jar" ]; then
  echo "ERROR, Not a valid server installation"
  exit 1
fi
if [ "$2" == "--transitive" ]; then
  echo "Enabling transitive scanning, will take time to retrieve shaded dependencies artifacts."
  if [ ! -n "${3}" ]; then
    echo "A list of remote maven repositories URL must be provided to check transitivity"
    exit 1
  fi
  mavenRepos="${3}"
  enableTransitive="true"
fi
rm -rf shade-scanner-output
mkdir -p shade-scanner-output
echo "Scanned JARS are unzipped in shade-scanner-output directory."
FILES=$(find ${jbossHome}/modules/ -name \*.jar)
readarray ARR <<< "${FILES}"
numShaded=0
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
      numShaded=$((numShaded+1))
      array=()
      for p in "${pomsArray[@]}"; do
        p=$(echo $p|tr -d '\n')
        dir=$(dirname $p)
        props=$dir/pom.properties
        version=`cat $props | grep "version" | cut -d'=' -f2`
        version=$(echo $version|tr -dc '[:print:]')
        groupId=`cat $props | grep "groupId" | cut -d'=' -f2`
        groupId=$(echo $groupId|tr -dc '[:print:]')
        x="${p#*shade-scanner-output/${jarFileName}/META-INF/maven/}"
        x=$(dirname $x)
        artifactId=$(basename $x)
        if [[ "$jarFileName" != "$artifactId-"* ]]; then
          allShadedJarsNoVersion="$allShadedJarsNoVersion $artifactId-"
          x=${x////:}
          hashmap["$artifactId-"]="$i[$x:$version]"
          array+=("$x:$version")
          if [ -n "$enableTransitive" ]; then
            scanTransitive $groupId $artifactId $version "$mavenRepos"
          fi
        fi
      done
      echo "$i shades " $(($len - 1)) " artifacts"
      sorted=($(for a in "${array[@]}"; do echo "$a"; done | sort))
      for dep in "${sorted[@]}"; do echo "  $dep"; done
     else
       checkSuspicious "${pomsArray[0]}"
     fi
   else
     handleNotMaven "${i}"
   fi
 fi
done

# Check for duplicates
# A shaded JAR being a module artifact possibly with different version
numDuplicates=0
echo " "
echo "DUPLICATES (known shaded dependency)"
read -r -a ALLSHADEDNOVERSION <<< "${allShadedJarsNoVersion}"
read -r -a TRANSITIVESHADEDNOVERSION <<< "${transitiveShadedJarsNoVersion}"
read -r -a ALLJARS <<< "${allJars}"
  for i in "${ALLJARS[@]}"; do
      for j in "${ALLSHADEDNOVERSION[@]}"; do
        if [[ "$i" == $j*".jar" ]]; then
          numDuplicates=$((numDuplicates+1))
          echo "WARNING: ${modulesMap[$i]} is shaded in: ${hashmap[$j]}"
        fi
      done
      for j in "${TRANSITIVESHADEDNOVERSION[@]}"; do
        if [[ "$i" == $j*".jar" ]]; then
          numDuplicates=$((numDuplicates+1))
          echo "WARNING: ${modulesMap[$i]} is shaded in a TRANSITIVE dependency:" ${transitiveJarMap[$j]}
        fi
      done
  done

if [ "$numDuplicates" == "0" ]; then
  echo "NONE"
fi

printTransitives

printSuspicious

printNotMaven

echo "SCANNING DONE."
echo "* ${#ARR[@]} jars in modules"
echo "* ${numShaded} shaded jars"
echo "* ${numDuplicates} duplicates"
echo "* ${unknown} can't determinate"
echo "* ${suspiciousLen} are suspicious, check pom.xml files"