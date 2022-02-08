#!/bin/sh

rm -rf shaded-scan-output
mkdir -p shaded-scan-output
FILES=$(find modules/ -name \*.jar)
readarray ARR <<< "${FILES}"
notMaven=
allJars=
allShadedJarsNoVersion=
declare -A hashmap
declare -A modulesMap
for i in "${ARR[@]}"; do
 jarFileName=$(basename "${i}")
 modulesMap["$jarFileName"]="$(echo $i|tr -d '\n')"
 allJars="$allJars $jarFileName"
 if [ ! -d "shaded-scan-output/${jarFileName}" ]; then
   mkdir -p "shaded-scan-output/${jarFileName}"
   unzip $i -d shaded-scan-output/${jarFileName} 2>&1 > /dev/null
   if [ -d "shaded-scan-output/${jarFileName}/META-INF/maven" ]; then
     pomFiles=$(find shaded-scan-output/${jarFileName}/META-INF/maven -name pom.xml)
     readarray pomsArray <<< "${pomFiles}"
     len=${#pomsArray[@]}
     if [ "$len" != "1" ]; then
      echo "$i shades " $(($len - 1)) " artifacts"
      for p in "${pomsArray[@]}"; do
        p=$(echo $p|tr -d '\n')
        dir=$(dirname $p)
        props=$dir/pom.properties
        version=`cat $props | grep "version" | cut -d'=' -f2`
        x="${p#*shaded-scan-output/${jarFileName}/META-INF/maven/}"
        x=$(dirname $x)
        artifactId=$(basename $x)
        if [[ "$jarFileName" != "$artifactId-"* ]]; then
          allShadedJarsNoVersion="$allShadedJarsNoVersion $artifactId-"
          x=${x////:}
          hashmap["$artifactId-"]="$i[$x:$version]"
          echo "   $x:$version"
        fi
      done
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

echo "Jars that don't contain Maven metadata:"
echo "$notMaven"

