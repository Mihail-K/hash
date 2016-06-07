
module hashes;

import std.algorithm;
import std.conv;
import std.stdio;
import std.traits;
import std.variant;

/++
 + Tests if the given type is a hash.
 +/
enum isHash(Type : Hash!args, args...) = true;
/++
 + Ditto.
 +/
enum isHash(Type) = false;

/++
 + A templated datatype which stores key => value pairs.
 + Keys and values stored in hash need not be unique.
 +
 + Querying hashes can be done with both compile-time and run-time values.
 + ---
 + Hash!(a => 1) hash;
 +
 + assert(hash["a"] == Variant(1));
 + assert(hash.value!"a" == 1);
 + ---
 +
 + Hashes also allow for duplicate keys, and value selection by type.
 + ---
 + int xInt;
 + string xString;
 + Hash!(x => 5, x => "10") hash;
 +
 + hash.get("x", xInt);    // Or xInt    = hash.value!("x", int);
 + hash.get("x", xString); // Or xString = hash.value!("x", string);
 +
 + assert(xInt == 5);
 + assert(xString == "10");
 + ---
 +/
struct Hash(args...)
{
    // Internal use only.
    private struct HashType
    {
        // Nothing.
    }

    // Internal use only.
    private enum _valid = _isValidArgs;
    private static bool _isValidArgs()
    {
        enum invalidHashKey = "Type `%s` in Hash[index => %d] is not a valid key.";

        foreach(index, arg; args)
        {
            static if(!is(typeof(arg!HashType)))
            {
                import std.string : format;
                static assert(false, invalidHashKey.format(typeof(arg).stringof, index + 1));
                return false;
            }
        }

        return true;
    }

    /++
     + Applies the hash onto a value which is a class or struct given by `T`.
     +
     + Fields in the destination value are assigned for which there exists
     + an element with a matching key and type.
     +
     + For example,
     + ---
     + struct User
     + {
     +     string name;
     +     int age;
     +     bool admin;
     +     bool active;
     + }
     +
     + User user;
     + Hash!(name => "Jesse", age => 24, active => "yes").apply(user);
     +
     + assert(user.name == "Jesse"); // name => "Jesse"
     + assert(user.age  == 24);      // age  => 24
     + assert(user.admin == false);  // Unchanged (no key)
     + assert(user.active == false); // Unchanged (type mismatch)
     + ---
     +/
    static T apply(T)(auto ref T dest) if(is(T == class) || is(T == struct))
    {
        foreach(member; __traits(allMembers, T))
        {
            static if(hasKey(member))
            {
                alias T = typeof(__traits(getMember, dest, member));
                __traits(getMember, dest, member) = value!(member, T);
            }
        }

        return dest;
    }

    /++
     + Concatenates two hashes. Duplicate keys and values are preserved.
     +/
    static auto concat(other...)(Hash!other)
    {
        return Hash!(args, other).init;
    }

    /++
     + Tests for an empty hash.
     +/
    @property
    enum bool empty = args.length == 0;

    /++
     + Fetches an element by its runtime name and stores it into the
     + destination parameter.
     +/
    static bool get(T)(string name, out T dest)
    {
        foreach(arg; args)
        {
            alias key = arg!HashType;
            static if(is(FunctionTypeOf!key Types == __parameters))
            {
                static if(isAssignable!(T, typeof(key(HashType.init))))
                {
                    if(name == __traits(identifier, Types))
                    {
                        dest = key(HashType.init);
                        return true;
                    }
                }
                else static if(is(T == Variant))
                {
                    if(name == __traits(identifier, Types))
                    {
                        dest = Variant(key(HashType.init));
                        return true;
                    }
                }
            }
        }

        return false;
    }

    /++
     + Checks for the presence of a key in the hash.
     +/
    static bool hasKey()(string name)
    {
        return keys.countUntil(name) != -1;
    }

    /++
     + Ditto, but accepts a template parameter.
     +/
    enum bool hasKey(string name) = hasKey(name);

    /++
     + Unique set of key names in the hash. The order of keys is unspecified.
     +/
    @property
    enum string[] keys = _keys;

    private static string[] _keys()
    {
        bool[string] keySet;

        foreach(arg; args)
        {
            alias key = arg!HashType;
            static if(is(FunctionTypeOf!key Types == __parameters))
            {
                enum name = __traits(identifier, Types);
                if(name !in keySet)
                {
                    keySet[name] = true;
                }
            }
        }

        return keySet.keys;
    }

    /++
     + Returns the number of values in the hash.
     +/
    @property
    enum size_t length = args.length;

    /++
     + Iterates over the values in the hash as Variants.
     +/
    static int opApply(scope int delegate(Variant) dg)
    {
        foreach(arg; args)
        {
            alias key = arg!HashType;
            static if(is(FunctionTypeOf!key Types == __parameters))
            {
                auto value = Variant(key(HashType.init));

                if(int result = dg(value))
                {
                    return result;
                }
            }
        }

        return 0;
    }

    /++
     + Concatenates two hashes. Duplicate keys and values are preserved.
     +/
    static auto opBinary(string op : "~", other...)(Hash!other o)
    {
        return concat(o);
    }

    /++
     + Ditto, but also iterates over keys.
     +/
    static int opApply(scope int delegate(string, Variant) dg)
    {
        foreach(arg; args)
        {
            alias key = arg!HashType;
            static if(is(FunctionTypeOf!key Types == __parameters))
            {
                enum name  = __traits(identifier, Types);
                auto value = Variant(key(HashType.init));

                if(int result = dg(name, value))
                {
                    return result;
                }
            }
        }

        return 0;
    }

    /++
     + Fetches a value from the hash as a Variant.
     +/
    static Variant opIndex(string name)
    {
        Variant value;
        get(name, value);
        return value;
    }

    /++
     + Returns a value from the hash by name.
     +
     + If the type parameter `T` is given, the value returned must match `T`.
     + If no values with with matching a matching key and type exist within the
     + hash, `T.init` is returned instead.
     +
     + Params:
     +   name = The name of the key to search for.
     +   T    = An optional type constraint.
     +/
    @property
    static auto value(string name, T...)() if(hasKey(name) && T.length < 2)
    {
        static if(T.length == 1)
        {
            T[0] result = T[0].init;
        }

        foreach(arg; args)
        {
            alias key = arg!HashType;
            static if(is(FunctionTypeOf!key Types == __parameters))
            {
                static if(name == __traits(identifier, Types))
                {
                    static if(T.length == 0)
                    {
                        return key(HashType.init);
                    }
                    else static if(isAssignable!(T, typeof(key(HashType.init))))
                    {
                        result = key(HashType.init);
                    }
                }
            }
        }

        static if(T.length == 1)
        {
            return result;
        }
    }

    /++
     + Returns all values in the hash converted to a type given by `T`.
     +/
    @property
    static T[] values(T = Variant)()
    {
        T[] values;

        foreach(arg; args)
        {
            alias key = arg!HashType;
            values   ~= to!T(key(HashType.init));
        }

        return values;
    }
}

/++
 + Automatically initializes static fields from Hash-style parameters.
 + Only valid in structs and classes.
 +/
mixin template Hashify(args...)
{
    static this()
    {
        enum aggregate = is(typeof(this) == class) || is(typeof(this) == struct);
        static assert(aggregate, "Can only hashify struct or class.");

        Hash!(args).apply(typeof(this).init);
    }
}

/++
 + Shortcut for `Hash!(args).init`
 +/
auto hash(args...)()
{
    return Hash!(args).init;
}

unittest
{
    assert( isHash!(Hash!(a => 1, b => 2)));
    assert(!isHash!(bool));
    assert(!isHash!(string));
    assert(!isHash!(bool[string]));
    assert( isHash!(Hash!()));
    assert( isHash!(Hash!(a => 1, a => 2, a => 3)));
    assert(!isHash!(Object));
}

unittest
{
    assert(!__traits(compiles, {
        Hash!(
            a => 1,
            b => 2,
            c => 3,
            false
        ) hash;
    }));
}

unittest
{
    int x, y, z;
    Hash!(
        x => 1,
        y => 2,
        z => 3
    ) hash;

    assert(hash.hasKey("x"));
    assert(hash.hasKey("y"));
    assert(hash.hasKey("z"));

    assert(hash.length == 3);
    assert(hash.keys   == [ "x", "y", "z" ]);

    assert(hash.values        == [ Variant(1), Variant(2), Variant(3) ]);
    assert(hash.values!string == [ "1", "2", "3" ]);
    assert(hash.values!int    == [ 1, 2, 3 ]);

    assert(hash.get("x", x));
    assert(hash.get("y", y));
    assert(hash.get("z", z));

    assert(hash["x"] == Variant(1));
    assert(hash["y"] == Variant(2));
    assert(hash["z"] == Variant(3));

    assert(x == 1);
    assert(y == 2);
    assert(z == 3);
}

unittest
{
    auto test = hash!(
        x => "foo",
        y => "bar",
        z => hash!(
            a => 1,
            b => 2
        )
    );

    assert(test.value!"x" == "foo");
    assert(test.value!"y" == "bar");
    assert(test.value!"z".value!"a" == 1);
    assert(test.value!"z".value!"b" == 2);
}

unittest
{
    struct Test
    {
        int x;
        int y;
        int z;
    }

    Test test;
    Hash!(
        x => 1,
        y => 2,
        z => 3
    ) hash;

    hash.apply(test);
    assert(test.x == 1);
    assert(test.y == 2);
    assert(test.z == 3);
}

unittest
{
    static struct Test(args...)
    {
        mixin Hashify!args;

        static
        {
            int a;
            int b;
            int c;
        }
    }

    Test!(
        a => 1,
        b => 2,
        c => 3
    ) test;

    assert(test.a == 1);
    assert(test.b == 2);
    assert(test.c == 3);
}

unittest
{
    static struct Column(args...)
    {
        mixin Hashify!args;

        static
        {
            string name;
            string type;
            bool nullable;
            string defaultValue;
        }
    }

    class User
    {
        @Column!(
            name => "nick_name",
            nullable => true
        )
        string nickname;
    }

    import std.meta : Alias;
    static assert(__traits(getAttributes, User.nickname).length == 1);
    alias NicknameColumn = Alias!(__traits(getAttributes, User.nickname)[0]);

    NicknameColumn column;
    assert(column.name == "nick_name");
    assert(column.nullable == true);
}

unittest
{
    struct Test
    {
        int x;
        int y;
        int z;

        this(H)(H hash) if(isHash!H)
        {
            hash.apply(this);
        }
    }

    Test test = Test(hash!(
        x => 2,
        y => 3,
        z => 4
    ));

    assert(test.x == 2);
    assert(test.y == 3);
    assert(test.z == 4);
}

unittest
{
    auto a = hash!(a => 1, b => 2);
    auto b = hash!(b => 3, c => 4);
    auto c = a ~ b;

    assert(c.length == 4);
    assert(c.values!int == [ 1, 2, 3, 4 ]);
}
