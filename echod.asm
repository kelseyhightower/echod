;; Copyright 2017 Google Inc. All Rights Reserved.
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;     http://www.apache.org/licenses/LICENSE-2.0
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

section .data
  buffer_len             equ  1024
  caught_sigint_msg      db   'Shutting down echod...', 0x0a
  caught_sigint_msg_len  equ  $-caught_sigint_msg
  startup_msg            db   'Starting echod...', 0x0a
  startup_msg_len        equ  $-startup_msg

section .bss
  accept_socket:   resd 1
  buffer:          resb 1024
  socket:          resd 1
  connection:      resd 1
  socket_address:  resd 2

section .text
  ;--------------------------------------------------------
  ; strlen
  ;   returns the length of the given string.
  ; args:
  ;   esi = address of a NULL (0) terminated string.
  ; out:
  ;   eax = the string length.  
  ;--------------------------------------------------------
  strlen:
    push ebx
    push ecx

    mov   ebx, edi            
    xor   al, al                               
    mov   ecx, 0xffffffff     
                                                     
    repne scasb

    sub   edi, ebx
    mov   eax, edi            

    pop ebx
    pop ecx
    ret                       

  ;--------------------------------------------------------
  ; exit
  ;   exit the program with the 0 exit code
  ;--------------------------------------------------------
  exit:
    mov  ebx, 0
    mov  eax, 1 ; sys_exit
    int  0x80

  ;--------------------------------------------------------
  ; sig_int_handler
  ;   trap the SIGINT signal, log, and exit.
  ;--------------------------------------------------------
  sig_int_handler:
    mov   edx, caught_sigint_msg_len
    mov   ecx, caught_sigint_msg
    call  sys_write_stderr
    jmp   exit

  ;--------------------------------------------------------
  ; sys_signal
  ;   registers the given handler with the given signal
  ; args:
  ;   ebx = the signal number to handle
  ;   ecx = the signal handler 
  ;--------------------------------------------------------
  sys_signal:
    push  eax
    mov   eax, 48 ; sys_signal
    int   0x80
    pop   eax
    ret

  ;--------------------------------------------------------
  ; sys_write_stderr
  ;   write the given message to standard error.
  ; args:
  ;   edx = the message length.
  ;   ecx = the null terminated string.
  ;--------------------------------------------------------
  sys_write_stderr:
    push  eax
    push  ebx
    mov   eax, 4
    mov   ebx, 2
    int   0x80
    pop   ebx
    pop   eax
    ret

  ;--------------------------------------------------------
  ; sys_write_stdout
  ;   write the given message to standard out.
  ; args:
  ;   edx = the message length.
  ;   ecx = the null terminated string.
  ;--------------------------------------------------------
  sys_write_stdout:
    push  eax
    push  ebx
    mov   eax, 4
    mov   ebx, 1
    int   0x80
    pop   ebx
    pop   eax
    ret

global _start
  _start:

  pop eax ; get argument counter
  pop ebx ; get command name (argv[0])

  ; get the command line arguments
  get_args:
    pop   ecx
    test  ecx, ecx
    jnz   get_args

  ; print all the env vars to stderr. At some
  ; point this section will be used to configure
  ; the server.
  get_env:
    pop   edx
    test  edx, edx
    je    next

    mov   edi, edx
    call  strlen

    mov   ecx, edx
    mov   edx, eax
    call  sys_write_stderr

    loop  get_env

next:
  ; log the startup message.
  mov   edx, startup_msg_len
  mov   ecx, startup_msg
  call  sys_write_stderr

  ; register a handler to trap the SIGINT signal so
  ; we can shutdown cleanly.
  mov   ebx, 2
  mov   ecx, sig_int_handler
  call  sys_signal

  ; create a TCP socket and start listening for requests
  ; on 0.0.0.0 port 5000.

  ; push the socket syscall arguments on the stack.
  push  dword 6                 ; TCP
  push  dword 1                 ; SOCK_STREAM	
  push  dword 2                 ; AF_INET

  ; socketcall syscall call
  mov  eax, 102                 ; sys_socketcall
  mov  ebx, 1                   ; invoke the socket function 
  mov  ecx, esp
  int  0x80
  mov  dword [socket], eax 

  ; creaet the sockaddr structure.
  push  dword 0x00000000        ; 0.0.0.0
  push  word  0x8813            ; port 5000
  push  word  2                 ; AF_INET
  mov   [socket_address], esp


  ; bind syscall arguments
  push  dword 16
  push  dword [socket_address]
  push  dword [socket]

  ; bind syscall
  mov  eax, 102                 ; sys_socketcall
  mov  ebx, 2                   ; bind()
  mov  ecx, esp                 ; arguments on the stack
  int  0x80


  ; listen syscall arguments
  push  byte 20
  push  dword [socket]

  ; listen syscall
  mov  eax, 102                 ; sys_socketcall
  mov  ebx, 4                   ; listen()
  mov  ecx, esp                 ; arguments on the stack
  int  0x80

; Read from the TCP socket until SIGINT.
accept_read_loop:
  ; accept syscall arguments
  push  0
  push  0
  push  dword [socket]

  ; accept syscall
  mov  eax, 102                 ; sys_socketcall
  mov  ebx, 5                   ; accept()
  mov  ecx, esp                 ; arguments on the stack
  int  0x80


  ; Read the from the socket and print to stdout.
  mov  dword [accept_socket], eax

  mov  eax, 3                   ; sys_read
  mov  ebx, [accept_socket]
  mov  ecx, buffer 
  mov  edx, buffer_len
  int  0x80

  mov  eax, 4                   ; sys_write
  mov  ebx, [accept_socket]
  mov  ecx, buffer
  mov  edx, buffer_len
  int  0x80

  mov  eax, 6                   ; sys_close
  mov  ebx, [accept_socket]
  int  0x80

  loop accept_read_loop
