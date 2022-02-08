# shade-scanner
Scan modules for shaded artifacts

* List dependencies(GAV) that are shaded by JBoss Modules jar artifacts.
* WARN for shaded dependency that also exist as JBoss Modules JAR artifacts. These ones are real duplicates.
* List all JAR artifacts that have not been built with Maven (no maven metadata).

Usage:
* cd into a JBOSS_HOME directory
* sh ./list-shaded.sh
* Output contains the scan result.
