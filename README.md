# echod

echod listens on 127.0.0.1 TCP port 5000 for client requests. echod sends any data it receives back to the client.

## Usage

```
echod
```

```
echo "hello" | nc 127.0.0.1 5000
```

## Build

The following steps work on Linux machines.

Compile:

```
nasm -f elf32 echod.asm
```

Link:

```
ld -m elf_i386 -s -o echod echod.o
```
