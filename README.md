# shade-scanner
Scan modules or individual Jar file for direct and transitive shaded artifacts.

## Scan module artifacts 

* List dependencies (GAV) that are shaded by JBoss Modules jar artifacts.
* List transitive dependencies (GAV) that are shaded by JBoss Modules jar artifacts.
* Warns for shaded dependency that can also exist as JBoss Modules JAR artifacts. These ones are real duplicates. Double check that 
the warning is correct, we are identifying this case based on jar name (so artifactId only). A scan done on WF27 snapshot shows valid warnings.
* The jars that don't contain maven metadata are ignored. We can't determinate any shaded dependencies for these.
* jars that contain Maven metadata but are not shading dependencies are flagged as suspicious if they are using: ``shading maven-shade-plugin`` or ``assembly-maven-plugin`` or ``unpack-dependencies``

Usage:
* ``sh ./list-shaded.sh <absolute path to a server installation> [--transitive <comma separated list of maven repo URL>] ``
* Scanning for transitives implies download of artifacts from remote repositories, can take some time.
* Output contains the scan result.

## Scan a JAR file

* List dependencies (GAV) that are shaded by the JAR file.
* Output contains the scan result.
* The jars that don't contain maven metadata are ignored. We can't determinate any shaded dependencies for these.
* jars that contain Maven metadata but are not shading dependencies are flagged as suspicious if they are using: ``shading maven-shade-plugin`` or ``assembly-maven-plugin`` or ``unpack-dependencies``

Usage:
* ``sh ./scan-jar.sh <path to JAR file> [--transitive <comma separated list of maven repo URL>]``
* Scanning for transitives implies download of artifacts from remote repositories, can take some time.
* Output contains the scan result.