#!/bin/bash
# EmulationStation Ports entry for the Dirtywave M8 headless client.
#
# Goes at /roms/ports/M8.sh - the TOP level, alongside the M8/ directory.
# ArkOS defines its Ports system in /etc/emulationstation/es_systems.cfg as:
#
#   <path>/roms/ports/</path>
#   <extension>.sh .SH</extension>
#   <command>sudo perfmax %GOVERNOR% %ROM%; nice -n -19 /usr/local/bin/AltSDL.sh %ROM%; sudo perfnorm</command>
#
# so ES lists *.sh found there. With only directories present and no script at
# the top level, nothing appears in the menu. This is the single clean "M8"
# entry; it hands off to the real launcher, which handles audio routing, the
# CPU governor and m8c itself.
exec /roms/ports/M8/M8.sh "$@"
