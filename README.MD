# STOS

### Why make an Operating System today?

Because we felt the need for something simple, that combines what's good about  past and modern technoligies.

This project takes inspiration from the [Suckless philosofy](https://suckless.org) at it's core.


## How-To (use edition)
Step 1: Go in releases  
Step 2: Download the latest STOS.iso file  
Step 3: You are on your own. Emulate it, burn it, your choice  
(we do not take responsibility for any damage)  

## How-To (compile edition)
Step 1: Git it  
Step 2: get in that folder  
Step 3: run `make`   
Step 4: run it (if you have quemu you can just use `./run.sh`)   


### Objectives for The Future
<details open>

<summary>
    #### Short term
</summary>
- [x] Making the system bootable 
- [x] Stop using ASM get C
- [x] give printf to C
- [ ] give some kind of scanf to C
</details>
<details open>

<summary><h4>Medium term</h4></summary>
- [ ] Implement a simple shell
- [x] Make the FileSystem (we got fat12 for now)
</details>
<details open>

<summary>
    #### Long term
</summary>
- [ ] Networking
- [ ] Full Keyboard integration
- [ ] Full Mouse integration
- [ ] Window manager
- [ ] A way to run executables
- [ ] Implement a simple file manager
- [ ] Implement a simple text editor
</details>

## Sauce
Every doc or wiki where we got the information out of:
- [OSDev](https://osdev.org)
- Ace's old failed attempt [AceOS](https://github.com/Ace-69/AceOS)
- [NASM](https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/doc/nasmdoc.pdf)
- [Intel Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html#combined)
- [Open watcom](https://github.com/open-watcom/open-watcom-v2) docs found in install dir
