
import std.algorithm;
import std.conv;
import std.stdio;
import std.traits;
import std.variant;

enum isHash(Type : Hash!args, args...) = true;
enum isHash(Type) = false;

struct Hash(args...)
{
    private static struct HashType
    {
        // Nothing.
    }

    static T apply(T)(auto ref T dest)
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

    @property
    enum bool empty = args.length == 0;

    static bool get(T)(string name, auto ref T dest)
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

    static bool hasKey()(string name)
    {
        return keys.countUntil(name) != -1;
    }

    enum bool hasKey(string name) = hasKey(name);

    @property
    enum string[] keys = _keys;

    private static string[] _keys()
    {
        bool[string] keySet;

        foreach(index, arg; args)
        {
            static if(is(typeof(arg!HashType)))
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
            else
            {
                static assert(0, "Type `" ~ typeof(arg).stringof ~ "` at Hash[index => " ~
                                 text(index + 1) ~ "] is not a valid Hash key.");
            }
        }

        return keySet.keys;
    }

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

    static Variant opIndex(string name)
    {
        Variant value;
        get(name, value);
        return value;
    }

    @property
    static auto value(string name, T...)() if(hasKey(name) && T.length < 2)
    {
        foreach(arg; args)
        {
            alias key = arg!HashType;
            static if(is(FunctionTypeOf!key Types == __parameters))
            {
                static if(name == __traits(identifier, Types))
                {
                    static if(T.length == 0 || (T.length == 1 &&
                             isAssignable!(T, typeof(key(HashType.init)))))
                    {
                        return key(HashType.init);
                    }
                }
            }
        }
    }

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
        static
        {
            int a;
            int b;
            int c;
        }

        static this()
        {
            Hash!args.apply(typeof(this).init);
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
        static
        {
            string name;
            string type;
            bool nullable;
            string defaultValue;
        }

        static this()
        {
            Hash!args.apply(typeof(this).init);
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
