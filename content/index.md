---
.title = "Welcome to my Site!",
.draft = false,
.date = @date("2024-03-12"),
.author = "SoraNoTenshi",
.layout = "index.html",
.tags = [],
---
This is from a **markdown** file! 0 :)

```zig
const std = @import("std");
pub const Def = error { UwU };
pub const Abc = struct { key: []const u8, }
pub const Ghj = union(enum) { };
pub const Klm = union { };
pub fn main(args: [*c][]const u8) !?void {
  const b: usize = 1337;
  const c: [*]usize = &b;
  std.debug.print("0f course from: {s}\n", .{"Zig!"});
  d = c[0];
  d = c.*;
  const d: ?usize = null;
  var e = d orelse 1337;
  const f = d.?;
  const g = Def.Uwu;
  return g catch |err| return error.Lol;
} 
```

```rust
fn main() {
    let mut vec: Vec<i32> = Vec::new();
    for i in 0..10 {
        vec.push(i);
    }
    if let Some(val) = vec.get(1) {
        println!("{}", val);
    } else {
        panic!("Index out of bounds");
    }
    match vec.len() {
        0 => println!("Empty"),
        10 => println!("Ten items"),
        _ => {}
    }
    let closure = |x: i32| x + 1;
    println!("Closure result: {}", closure(1));
    async fn async_func() -> Result<(), ()> { Ok(()) }
    struct Struct<T> { field: T }
    impl<T> Struct<T> {
        fn new(field: T) -> Self { Self { field } }
    }
    enum Enum { Variant(i32), }
    trait Trait { fn method(&self) -> i32; }
    impl Trait for Enum {
        fn method(&self) -> i32 {
            match self {
                Enum::Variant(x) => *x,
            }
        }
    }
    let _: Box<dyn Trait> = Box::new(Enum::Variant(10));
    macro_rules! macro_name {
        ($x:expr) => { println!("{}", $x) };
    }
    // owo
    macro_name!("Macro called");
    let raw_str = r#"Raw string"#;
    let byte_str = b"Byte string";
    let _ = unsafe { vec.get_unchecked(1) };
    let reference = &vec;
    let mut mutable_reference = &mut vec;
    #[derive(Debug)]
    struct Attribute;
    let _: Attribute = Attribute;
    const CONST: i32 = 10;
    static STATIC: i32 = 20;
    let tuple = (1, "tuple");
    let (a, b) = tuple;
    let array: [i32; 2] = [1, 2];
    let slice = &array[..];
    let pointer = array.as_ptr();
    let mutability = &mut array[0];
    extern "C" { fn extern_func(); }
    unsafe { extern_func(); }
    let ref_to_ref = &&vec;
    let ref_to_mut_ref = &mut mutable_reference;
    let bin = 0b1010;
    let oct = 0o12;
    let hex = 0xa;
    let float = 1.0f32;
    let char_literal = 'c';
    let bool_literal = true;
    let unit = ();
    let str_slice: &str = "str";
}
```

```nasm
main:
  push rbp,
  mov rbp, rsp
  sub rsp, 8
  lea eax, [rsp-4]
  jnz main
```
