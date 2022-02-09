# shade-scanner
Scan modules for shaded artifacts.

* List dependencies(GAV) that are shaded by JBoss Modules jar artifacts.
* Warns for shaded dependency that can also exist as JBoss Modules JAR artifacts. These ones are real duplicates. Double check that 
the warning is correct, we are identifying this case based on jar name (so artifactId only). A scan done on WF27 snapshot shows valid warnings.
* The jars that don't contain maven metadata are ignored. We can't determinate any shaded dependencies for these.

Usage:
* sh ./list-shaded.sh [absolute path to a server installation]
* If no argument is provided the local directory is scanned.
* Output contains the scan result.
