Hacking Guide
=============

Key entrypoints
---------------
In the `lua/nerveux/init.lua` file, the `nerveux.setup` function is called by
the user and is responsible for setting up:

- configurable plugin options
- the neuron daemon handler
- mappings
- autocommands

The autocommands are responsible for updating the virtual titles via the
`update_virtual_titles` function which is triggered in and out of `Insert` and
when the contents of the buffer are read or written.

Virtual Titles
--------------
Main entrypoint: `update_virtual_titles`.



---

*This document was written for commit 2d21665b4a1352f7ee89c3f24ef852f7aea0bf55
and may not be up to date with the latest state of the code*
