# hash [![DUB](https://img.shields.io/dub/l/vibe-d.svg?maxAge=2592000)](#)
A Hash datatype for key => value pairs.

## What is a Hash?
Hashes serve as key-value pairs for arbitrary value types. Unlike associative arrays, Hashes are immutable, and values in a Hash need not all be the same type. For example, a Hash can store both `int` and `string` values at the same time,
```d
auto ex = hash!( foo => 1, bar => "2" );
```

### Reading Values

Since hashes store different kinds of values, `Variant` is used to wrap values read using run-time arguments. However, if read using compile-time (template) arguments, they always return values as their original type.
```d
auto ex = hash!( foo => 1, bar => "2" );

import std.variant;
// Run-time arguments
assert(ex["foo"] == Variant(1));
assert(ex["bar"] == Variant("2"));

// Template arguments
assert(ex.value!("foo") == 1);
assert(ex.value!("bar") == "2");
```

Values can also be read directly into a field or variable as follows:
```d
int foo;
string bar;

ex.get("foo", foo);
ex.get("bar", bar);

assert(foo == 1);
assert(bar == "2");
```

### Duplicate Keys

Unlike Hashes in other languages, the keys in a D Hash need not be unique.
```d
auto ex = hash!( foo => 5, foo => "10" );
```

We can actually distinguish between these values, and select them based on their types.
```d
assert(ex.value!("foo", int) == 5);       // foo => 5
assert(ex.value!("foo", string) == "10"); // foo => "10"
```

And when assigning values directly into fields, their types can are inferred from their destination.
```d
int fooInt;
string fooString;

ex.get("foo", fooInt);    // Inferred int
ex.get("foo", fooString); // Inferred string

assert(fooInt == 5);
assert(fooString == "10");
```

### Applying Hashes

One nifty feature the D Hash includes is the ability to apply itself to an aggregate type (a class or a struct) and assign values to fields based on their names and types.
```d
struct User
{
    string name;
    int age;
}

User user;
auto data = hash!( name => "Jesse", age => 24 );

data.apply(user);
assert(user.name == "Jesse");
assert(user.age == 24);
```

## License
MIT
