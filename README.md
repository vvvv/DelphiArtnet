DelphiArtnet
============

Utility library to talk Artnet 2, ie. DMX over ethernet

Note:
This unit won't run as is. You'll need to provide the two used units:
- Clock.pas (needs to provide a GClock)
- Events (needs to provide a multicast event implementation called TMEvents)

yourself. Both should be quite quite selfexplanatory to implement by looking at their usage in this unit. 
