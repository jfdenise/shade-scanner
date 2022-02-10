#!/bin/sh

declare -A transitiveMap
function scanTransitive() {
  local depGroupId="${1}"
  local depArtifactId="${2}"
  local depVersion="${3}"
  echo "Checking if shaded dependency $depGroupId:$depArtifactId:$depVersion shades dependencies"
  mkdir -p shade-scanner-output/transitives/downloads
  local downloadedJarFileName=$depArtifactId-$depVersion.jar
  local downloadedJar="shade-scanner-output/transitives/downloads/${downloadedJarFileName}"
  if [ -f "$downloadedJar" ]; then
    # Already scanned
    return
  fi
  
  mvn org.apache.maven.plugins:maven-dependency-plugin:2.4:get -Dtransitive=false -DremoteRepositories=https://maven.repository.redhat.com/ga,https://repository.jboss.org/nexus/content/groups/public-jboss/     -Dartifact="$depGroupId:$depArtifactId:$depVersion:jar"  -Ddest="${downloadedJar}" 2>&1 > /dev/null
  local retVal=$?
  if [ $retVal -ne 0 ]; then
    echo "ERROR getting transitive dependency $depGroupId:$depArtifactId:$depVersion:jar"
    return
  fi

  unzip "${downloadedJar}" -d "shade-scanner-output/transitives/${downloadedJarFileName}" 2>&1 > /dev/null
  if [ -d "shade-scanner-output/transitives/${downloadedJarFileName}/META-INF/maven" ]; then
    local transitiveArray=()
    local transitivePomFiles=$(find shade-scanner-output/transitives/${downloadedJarFileName}/META-INF/maven -name pom.xml)
    readarray transitivePomsArray <<< "${transitivePomFiles}"
    local transitiveLen=${#transitivePomsArray[@]}
    if [ "$transitiveLen" != "1" ]; then
      for transitivep in "${transitivePomsArray[@]}"; do
        transitivep=$(echo $transitivep|tr -d '\n')
        local transitivedir=$(dirname $transitivep)
        local transitiveprops=$transitivedir/pom.properties
        local transitiveversion=`cat $transitiveprops | grep "version" | cut -d'=' -f2`
        local transitivegroupId=`cat $transitiveprops | grep "groupId" | cut -d'=' -f2`
        local transitivex="${transitivep#*shade-scanner-output/transitives/${downloadedJarFileName}/META-INF/maven/}"
        local transitivex=$(dirname $transitivex)
        local transitiveartifactId=$(basename $transitivex)
        if [[ "$downloadedJarFileName" != "$transitiveartifactId-"* ]]; then
          transitivex=${transitivex////:}
          transitivearray+=("$transitivex:$transitiveversion")
          local transitiveString="$transitiveString $transitivex:$transitiveversion"
          echo "WARNING: Found transitive $transitivex:$transitiveversion in $depGroupId:$depArtifactId:$depVersion"
          scanTransitive $transitivegroupId $transitiveartifactId $transitiveversion
       fi
     done
     transitiveMap["$depGroupId:$depArtifactId:$depVersion"]=$transitiveString
   fi
fi
}

function printTransitives() {
transitiveLength=${#transitiveMap[@]}
if [ "$transitiveLength" != "0" ]; then

  echo " "
  echo "TRANSITIVE DEPENDENCIES"
  echo " " 
  for key in "${!transitiveMap[@]}"
  do
    local deps=${transitiveMap[$key]}
    read -r -a depsArray <<< "${deps}"
    local depsSorted=($(for adep in "${depsArray[@]}"; do echo "$adep"; done | sort))
    local depsLen=${#depsSorted[@]}
    echo "$key shades " $(($depsLen)) " artifacts"
    for trans in "${depsSorted[@]}"; do 
      echo "  $trans"
    done
  done
fi
}
