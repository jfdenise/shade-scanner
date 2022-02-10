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
      array=()
      for p in "${pomsArray[@]}"; do
        p=$(echo $p|tr -d '\n')
        dir=$(dirname $p)
        props=$dir/pom.properties
        version=`cat $props | grep "version" | cut -d'=' -f2`
        groupId=`cat $props | grep "groupId" | cut -d'=' -f2`
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
     fi
   else
     notMaven="$notMaven$i"
   fi
 fi
done

# Check for duplicates
# A shaded JAR being a module artifact possibly with different version
read -r -a ALLSHADEDNOVERSION <<< "${allShadedJarsNoVersion}"
read -r -a TRANSITIVESHADEDNOVERSION <<< "${transitiveShadedJarsNoVersion}"
read -r -a ALLJARS <<< "${allJars}"
  for i in "${ALLJARS[@]}"; do
      for j in "${ALLSHADEDNOVERSION[@]}"; do
        if [[ "$i" == $j*".jar" ]]; then
          echo "WARNING: ${modulesMap[$i]} is shaded in: ${hashmap[$j]}"
        fi
      done
      for j in "${TRANSITIVESHADEDNOVERSION[@]}"; do
        echo "TRANSITIVE $j ==> ${transitiveJarMap[$j]}"
        if [[ "$i" == $j*".jar" ]]; then
          echo "WARNING: ${modulesMap[$i]} is shaded in a TRANSITIVE dependency:" ${transitiveJarMap[$j]}
        fi
      done
  done

printTransitives

