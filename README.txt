++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
File injector for PCem/86Box, v0.1                viler@int10h.org, 2020-04-15
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



DESCRIPTION

  A quick-and-dirty tool to enable easy, automated file transfers from a
  Windows host to a running machine in PCem/86Box (especially if it runs DOS).
  No need to shut down/restart the emulator, to set up virtual networking, or
  to manually create/mount/eject floppy disk images.
  
  This tool uses the disk image approach, but does it transparently, in one
  click.  Useful if you tend to update sets of files very often - for example,
  if you do your DOS programming with native Windows tools on the host PC, and
  switch to the emulator for quick testing and debugging (this was my own
  motivation for making it).



REQUIREMENTS

  * PCem (tested with v15) or 86Box (tested with v2.07)
  
  * ImDisk Virtual Disk Driver (http://www.ltr-data.se/opencode.html/#ImDisk)
  


CONTENTS

  PCemuFileInjector.exe (MD5 = 51eb345980b89a853fdb88a846946781)



USAGE

  Just run File Injector, choose the appropriate options on the right, and
  select (or drag & drop) the files you want to copy.
  
  Whenever you have the emulator window open at the DOS prompt, you can simply
  click "Inject files", and it'll do all the work for you - including COPY/
  XCOPY commands, if you select the respective option.



OPTIONS

  The on-screen labels should be self-explanatory, but here goes:
  
  * Temporary disk image size: covers the likely diskette formats, from
    360 KB (5.25" DD) up to 2880 KB (3.5" ED).  
    
  * Emulator: the choices specify the PCem and 86Box versions which I actually
    tested, but it should work just fine with other/future versions as long as
    they retain the relevant menu controls.
    
  * Mount As: the emulated drive letter to be used in the PCem or 86Box guest.
  
  * Action to be performed after mounting:
    - Do nothing (just keeps the disk image in the drive)
    - COPY files to the current DOS working directory ("copy #:\*.* /y")
    - XCOPY files and folders to the current DOS working directory
      ("xcopy #:\*.* /e /y")
      ("#" is replaced with the drive letter selected in the previous option)

  * Debug output: adds verbose logging during the automated process; can be
    useful for troubleshooting.
    


DETAILS

  So how does this work, exactly?

  * First, the tool looks for an unused drive letter on the host, and for an
    active PCem/86Box window (depending on your selection); in the emulator
    window, it ejects any current floppy image in the chosen drive, to avoid
    conflicts.

  * Back on the host side, it calls ImDisk to create a new diskette image in
    your %TEMP% folder, format it at the selected size, and attach it to the
    unused drive letter.

  * If all is well, it copies your selected files/folders to the virtual disk,
    and releases the temporary drive letter.  Sometimes it takes a short while
    for all resources to unlock, so it tries to disengage politely first - if
    that fails 5 times, it does a forced eject.

  * Was everything copied successfully?  If so, it switches to the emulator
    window and mounts the temporary image.

  * If you picked the COPY or XCOPY options, it will also send the respective
    DOS command as keystrokes, so that means the guest machine has to be at
    the DOS prompt in the target directory.



NOTES/DISCLAIMER

  * Problems should be rare, but I've only tested this on two host machines
    (one running Win7, one Win10) so I don't really know - if there are any
    major issues, and the debug output is no help, feel free to contact.

  * This is a public domain release.  Also, no obligations or warranties are
    given - whatever happens, I will not be held responsible.

  * (During development, one of my work-in-progress versions somehow trigged a
    false positive antivirus alert, but the finished version didn't, so I hope
    you don't get one either.)
