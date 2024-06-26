---
.title = "Writing my first Windows Driver in Zig",
.draft = false,
.date = @date("2024-05-03"),
.author = "SoraNoTenshi",
.layout = "blog/blog.html",
.tags = [],
---

# The beginning

A friend of mine was working on some driver and i just thought to myself: well, wouldn't it be nice
if i could just write a Windows Driver in Zig?

Since i always wanted to experiment around with the WDK, i figured, why not?
So there the journey began.

## Setting up Zig for WDK

First things first: I of course looked around the MSDN to find some information on what to do, 
also with the help of my friend i could figure out *some* of the basics required for it, such as:
- Entry point
- required Headers
- and most of the linker options, but we'll get to that in a bit.

So i started to write a simple driver entry point in Zig, which looks like that:
```zig
const win = @import("std").os.windows;
const wdk = @cImport({
    @cDefine("_AMD64_", "1");
    @cInclude("ntifs.h");
    @cInclude("ntddk.h");
    @cInclude("wdm.h");
    @cInclude("ntstrsafe.h");
    @cInclude("ntimage.h");
    @cInclude("fltkernel.h");
});

pub fn driverEntry(_: wdk.PDRIVER_OBJECT, _: *const wdk.UNICODE_STRING) callconv(.C) wdk.NTSTATUS {
    const owo: *const [35:0]u8 = "OwO What's this? \nUwU *nuzzles you*";
    _ = wdk.DbgPrintEx(wdk.DPFLTR_IHVDRIVER_ID, wdk.DPFLTR_ERROR_LEVEL, owo);
    return 0;
}

comptime {
    @export(driverEntry, .{ .name = "DriverEntry" });
}
```
This for now should just write something to the kernel debugger. (To be fair, i am not yet advanced
enough to *fully* understand what the `ComponentId` as well as `Level` is for, but i'll probably
get there eventually!)

Now to one of the interesting part, the `build.zig`.
Since my development environment is at least for personal projects (at the moment) on Windows 11 inside
a WSL2 instance running NixOS, i was hoping that Zig could just compensate for the cross-platform "issue".
<details>it did.</details>
<p>Setting up paths to the WDK headers was relatively simple, however one thing to note is, that i am
not Linking the Compiler emition, but rather keep the Object, export it and then link it manually:</p>

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const wdk_path = "/mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22000.0";
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addObject(.{
        .name = "wdk-zig",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(.{
            .os_tag = .windows,
            .abi = .msvc,
        }),
        .optimize = optimize,
    });
    lib.addIncludePath(.{ .path = "/mnt/c/Program Files/Microsoft Visual Studio/2022/Preview/VC/Tools/MSVC/14.40.33521/include" });
    lib.addIncludePath(.{ .path = "/mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0/km" });
    lib.addIncludePath(.{ .path = wdk_path ++ "/shared" });
    lib.addIncludePath(.{ .path = wdk_path ++ "/ucrt" });

    const install_step = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = "obj" } },
    });

    b.getInstallStep().dependOn(&install_step.step);
}
```
Ah yes, don't we all love some hardcoded paths?
Well no, but for a PoC this is more than good enough.
The build script will just tell the Zig Compiler where to find the `C-Headers` and where to place
the emitted `obj` file "$PWD/zig-out/obj/wdk-zig.obj".

# Fixing the translate-c output

## nitfs.h

Now after my first `zig build` run, i get the following output:
```
❯❯ zig build
install
└─ install wdk-zig
   └─ zig build-obj wdk-zig Debug native-windows-msvc 2 errors
/home/nightmare/dev/wdk-zig/zig-cache/o/1cb55a6fa036465e3b4d628a218e655b/cimport.zig:23760:19: 
error: identifier cannot be empty
    localAdvHdr.*.@"".Flags |= @as(UCHAR, @bitCast(@as(i8, @truncate(@as(c_int, 64)))));
                  ^~~
src/main.zig:2:13: error: C import failed: AnalysisFail
const wdk = @cImport({
            ^~~~~~~~
referenced by:
    driverEntry: src/main.zig:17:23
    remaining reference traces hidden; use '-freference-trace' to see all reference traces
```

Well this doesn't look good, but let's dig into the actual error and what we see is this function:

```zig
pub inline fn FsRtlSetupAdvancedHeader(arg_AdvHdr: PVOID, arg_FMutex: PFAST_MUTEX) void {
    var AdvHdr = arg_AdvHdr;
    _ = &AdvHdr;
    var FMutex = arg_FMutex;
    _ = &FMutex;
    var localAdvHdr: PFSRTL_ADVANCED_FCB_HEADER = @as(PFSRTL_ADVANCED_FCB_HEADER, @ptrCast(@alignCast(AdvHdr)));
    _ = &localAdvHdr;
    // Compile error happens here
    localAdvHdr.*.@"".Flags |= @as(UCHAR, @bitCast(@as(i8, @truncate(@as(c_int, 64)))));
    localAdvHdr.*.@"".Flags2 |= @as(UCHAR, @bitCast(@as(i8, @truncate(@as(c_int, 2)))));
    localAdvHdr.*.@"".Version = @as(UCHAR, @bitCast(@as(i8, @truncate(@as(c_int, 4)))));
    // ...
}
```
Well this code certainly doesn't look right, but having a look at where `localAdvHdr` is actually defined, it gives
a good clue as to what went wrong.

First: Let's go into the `ntifs.h` and search for `localAdvHdr` and we can find a function that looks familiar:

```c
_IRQL_requires_max_(APC_LEVEL)
VOID
FORCEINLINE
FsRtlSetupAdvancedHeader(
    _In_ PVOID AdvHdr,
    _In_ PFAST_MUTEX FMutex )
{
    PFSRTL_ADVANCED_FCB_HEADER localAdvHdr = (PFSRTL_ADVANCED_FCB_HEADER)AdvHdr;

    localAdvHdr->Flags |= FSRTL_FLAG_ADVANCED_HEADER;
    localAdvHdr->Flags2 |= FSRTL_FLAG2_SUPPORTS_FILTER_CONTEXTS;

#if (NTDDI_VERSION >= NTDDI_WIN10_CO)
    localAdvHdr->Version = FSRTL_FCB_HEADER_V4;
#elif (NTDDI_VERSION >= NTDDI_WINBLUE)
    localAdvHdr->Version = FSRTL_FCB_HEADER_V3;
#elif (NTDDI_VERSION >= NTDDI_WIN8)
    localAdvHdr->Version = FSRTL_FCB_HEADER_V2;
#elif (NTDDI_VERSION >= NTDDI_VISTA)
    localAdvHdr->Version = FSRTL_FCB_HEADER_V1;
#else
    localAdvHdr->Version = FSRTL_FCB_HEADER_V0;
#endif

    InitializeListHead( &localAdvHdr->FilterContexts );

    if (FMutex != NULL) {

        localAdvHdr->FastMutex = FMutex;
    }
```

Now this looks like the thing we're missing, and since we see a direct access to the flags, we can safely
assume that we just need to fix the optional. Which then results into:

```zig
    localAdvHdr.?.*.Flags |= @as(UCHAR, @bitCast(@as(i8, @truncate(@as(c_int, 64)))));
    localAdvHdr.?.*.Flags2 |= @as(UCHAR, @bitCast(@as(i8, @truncate(@as(c_int, 2)))));
    localAdvHdr.?.*.Version = @as(UCHAR, @bitCast(@as(i8, @truncate(@as(c_int, 4)))));
```
and this causes us to get the next error. Of course... :(

## wdm.h

Next compile error is the following:
```
❯❯ zig build
install
└─ install wdk-zig
   └─ zig build-obj wdk-zig Debug native-windows-msvc 1 errors
/home/nightmare/dev/wdk-zig/zig-cache/o/1cb55a6fa036465e3b4d628a218e655b/cimport.zig:1524:16: 
error: opaque types have unknown size and therefore cannot be directly embedded in unions
    unnamed_0: struct_unnamed_41,
               ^~~~~~~~~~~~~~~~~
/home/nightmare/dev/wdk-zig/zig-cache/o/1cb55a6fa036465e3b4d628a218e655b/cimport.zig:1521:27: 
note: opaque declared here
const struct_unnamed_41 = opaque {};
                          ^~~~~~~~~
error: the following command failed with 1 compilation errors:
```

Digging into this error as well, we even have an immediate clue as to what happened, thanks to `translate-c`.

```zig
// /mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0/km/wdm.h:17935:27: warning: struct demoted to opaque type - has bitfield
const struct_unnamed_44 = opaque {};
```

because `translate-c` is not yet able to correctly determine the underlying memory layout, we of course have to take a look at this, too!
Thankfully, we immediately see the line where this happened:

```c
struct {
    UCHAR Timer2Inserted : 1;
    UCHAR Timer2Expiring : 1;
    UCHAR Timer2CancelPending : 1;
    UCHAR Timer2SetPending : 1;
    UCHAR Timer2Running : 1;
    UCHAR Timer2Disabled : 1;
    UCHAR Timer2ReservedFlags : 2;
} DUMMYSTRUCTNAME;
```
`(+ 1 1 1 1 1 1 2)` -> 8. So a full byte is necessary here.
We can easily just make this a `u8` because... well.. we don't actually care about this struct, we
just want it to have the same memory layout.

(This will be done with all of the following errors, so yeah a lot of bitfield counting!)

<details>Of course i was too lazy to handle all of those cases properly, so for now i just replaced
everything with `*anyopaque`, praying that it all just works as expected. I am not calling myself a
Hacker without a reason :p</details>

# Next steps
Now, running `zig build` lead to the following:
```
❯❯ zig build
┌──[  ]──[ ~/dev/wdk-zig ]──[ main ≢   ?16 -1 ]───[ 20:43:36 ]
└──[ nightmare@plutonium ]──❯❯
```

i was... shocked?
So i ran it again, but this time with `--summary all`

```
❯❯ zig build --summary all
Build Summary: 3/3 steps succeeded
install cached
└─ install wdk-zig cached
   └─ zig build-obj wdk-zig Debug native-windows-msvc cached 2ms MaxRSS:36M
```
HOLDUP?! It just... compiled?

Okokokokok, i kinda thought that something went wrong there in the compilation, so i just ran
`strings ./zig-out/bin/wdk-obj.obj | grep Driver`
And see for yourself:

```
❯❯ strings zig-out/obj/wdk-zig.obj | grep Driver
DriverStart
DriverSize
DriverSection
DriverExtension
DriverName
DriverInit
DriverStartIo
DriverUnload
DriverObject
DriverObject
DriverContext
DriverEntry
```
Well this certainly does look... very good, indeed!

## Linking

Linking was, less trivial than i thought, on WSL i am mostly able to run `.exe` files, but for linking
this sort of didn't work when i was trying with `/SUBSYSTEM:native` so i just copied the object file
from WSL to Windows and ran the following linker command in powershell.

```
lld-link.exe /INCREMENTAL /TIME /MAP /DEBUG /DRIVER /NODEFAULTLIB /NODEFAULTLIB:libucrt.lib
/NODEFAULTLIB:libucrtd.lib /TSAWARE:NO /SECTION:.text,erp /SECTION:.rdata,rp /SECTION:.data,rwp
/SECTION:.pdata,rp /SECTION:00cfg,rp /SECTION:.retplne,r /SECTION:.voltbl,rw /SECTION:INIT,erd
/SUBSYSTEM:NATIVE /ENTRY:DriverEntry /NODEFAULTLIB:msvcrt.lib
'C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\km\x64\ntoskrnl.lib'
'C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\km\x64\hal.lib'
'C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\km\x64\wmilib.lib'
/OPT:REF /MANIFEST:NO /OPT:ICF /SECTION:INIT,d  .\wdk-zig.obj -out:owo.sys
```

And oh yeah, this is a quite a lot, and most of it i don't understand myself (friend helped me again :p)
but the results show for itself:

```
lld-link: warning: ignoring '/incremental' because REF is enabled; use '/opt:noref' to disable
  Input File Reading:              10 ms ( 26.3%)
  GC:                               0 ms (  0.0%)
  ICF:                              0 ms (  0.0%)
  Code Layout:                      1 ms (  4.8%)
  Commit Output File:               0 ms (  0.6%)
  MAP Emission (Cumulative):        0 ms (  1.3%)
    Gather Symbols:                 0 ms (  0.0%)
    Build Symbol Strings:           0 ms (  0.2%)
    Write to File:                  0 ms (  1.1%)
  PDB Emission (Cumulative):        9 ms ( 24.1%)
    Add Objects:                    0 ms (  2.2%)
      Global Type Hashing:          0 ms (  1.0%)
      GHash Type Merging:           0 ms (  0.8%)
      Symbol Merging:               0 ms (  0.3%)
    Publics Stream Layout:          0 ms (  0.5%)
    TPI Stream Layout:              0 ms (  0.0%)
    Commit to Disk:                 8 ms ( 20.9%)
--------------------------------------------------
Total Linking Time:                38 ms (100.0%)
```
blabla yeah there is a warning, but who cares[[1](#1)] about warnings, am i right? :')
Now my friend is coming in clutch again, who already has a full Windows VM set up, including
a custom tool to load drivers, resulting in..........

![](./wdk_in_zig/working_driver.png)

And that's how i have written my first Windows Driver (and also have written my first blog post!).

### Footnote:

<a name="1">[1]</a> Of course i care about warnings, but only in serious, non-prototype Projects.
