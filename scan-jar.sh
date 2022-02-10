#!/bin/sh

  declare -A transitiveMap
function scanTransitive() {
  depGroupId="${1}"
  depArtifactId="${2}"
  depVersion="${3}"
  echo "Checking if shaded dependency $depGroupId:$depArtifactId:$depVersion shades dependencies"
  mkdir -p shade-scanner-output/transitives/downloads
  downloadedJarFileName=$depArtifactId-$depVersion.jar
  downloadedJar="shade-scanner-output/transitives/downloads/${downloadedJarFileName}" 
  #rm -rf "$downloadedJar"
  #mvn org.apache.maven.plugins:maven-dependency-plugin:2.4:get -Dtransitive=false -DremoteRepositories=https://maven.repository.redhat.com/ga,https://repo1.maven.org/maven2/,https://repository.jboss.org/nexus/content/groups/public-jboss/     -Dartifact="$depGroupId:$depArtifactId:$depVersion:jar"  -Ddest="${downloadedJar}"
  #retVal=$?
  #if [ $retVal -ne 0 ]; then
  #  echo "Error getting transitive dependency $depGroupId:$depArtifactId:$depVersion:jar"
  #  return
  #fi
  unzip "${downloadedJar}" -d "shade-scanner-output/transitives/${downloadedJarFileName}" 2>&1 > /dev/null
  if [ -d "shade-scanner-output/transitives/${downloadedJarFileName}/META-INF/maven" ]; then
    transitiveArray=()
    transitivePomFiles=$(find shade-scanner-output/transitives/${downloadedJarFileName}/META-INF/maven -name pom.xml)
    readarray transitivePomsArray <<< "${transitivePomFiles}"
    transitiveLen=${#transitivePomsArray[@]}
    if [ "$transitiveLen" != "1" ]; then
      
      for transitivep in "${transitivePomsArray[@]}"; do
        transitivep=$(echo $transitivep|tr -d '\n')
        transitivedir=$(dirname $transitivep)
        transitiveprops=$transitivedir/pom.properties
        transitiveversion=`cat $transitiveprops | grep "version" | cut -d'=' -f2`
        transitivegroupId=`cat $transitiveprops | grep "groupId" | cut -d'=' -f2`
        transitivex="${transitivep#*shade-scanner-output/transitives/${downloadedJarFileName}/META-INF/maven/}"
        transitivex=$(dirname $transitivex)
        transitiveartifactId=$(basename $transitivex)
        if [[ "$downloadedJarFileName" != "$transitiveartifactId-"* ]]; then
          transitivex=${transitivex////:}
          transitivearray+=("$transitivex:$transitiveversion")
          transitiveString="$transitiveString $transitivex:$transitiveversion"
       fi
     done
     transitivesorted=($(for transitivea in "${transitivearray[@]}"; do echo "$transitivea"; done | sort))
     transitiveMap["$depGroupId:$depArtifactId:$depVersion"]=$transitiveString
     #echo "PUT $transitiveString in $depGroupId:$depArtifactId:$depVersion"
     #for transitivedep in "${transitivesorted[@]}"; do echo "    $transitivedep"; done
   fi
fi
}

if [ ! -n "${1}" ]; then
  echo "A path to a jar must be provided"
  exit 1
fi
jarFile="$1"
if [ ! -f "${jarFile}" ]; then
 echo "The file ${jarFile} doesn't exist"
 exit 1
fi

#rm -rf shade-scanner-output
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
    groupId=`cat $props | grep "groupId" | cut -d'=' -f2`
    x="${p#*shade-scanner-output/${jarFileName}/META-INF/maven/}"
    x=$(dirname $x)
    artifactId=$(basename $x)
    if [[ "$jarFileName" != "$artifactId-"* ]]; then
      x=${x////:}
      array+=("$x:$version")
      #scanTransitive $groupId $artifactId $version
      #foundTransitives=${transitiveMap["$groupId:$artifactId:$version"]}
    fi
  done
  sorted=($(for a in "${array[@]}"; do echo "$a"; done | sort))
  for dep in "${sorted[@]}"; do 
    echo "  $dep";
    foundTransitives=${transitiveMap["$dep"]}
    if [ -n "$foundTransitives" ]; then
      readarray foundTransitivesArray <<< "${foundTransitives}"
      foundTransitivesSorted=($(for a in "${foundTransitivesArray[@]}"; do echo "$a"; done | sort))
      foundTransitiveLen=${#foundTransitivesSorted[@]}
      echo "   WARNING: $dep shades " $(($foundTransitiveLen)) " artifacts"
      for trans in "${foundTransitivesSorted[@]}"; do 
        echo "    $trans";
      done
    fi
  done
 fi
else
 echo "The jar $jarFileName doesn't contain Maven metadata, can't identofy shaded dependencies."
fi

