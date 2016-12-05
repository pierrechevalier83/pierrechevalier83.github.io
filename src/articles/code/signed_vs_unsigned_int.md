## A discussion about int types in C++

> unsigned semantic in C and C++ doesn't really mean "not negative" but it's more like "bitmask" or "modulo integer".

### Old-style for loops

Working on any large C++ codebase that predates C++11, one is bound to find a number of old style loops:<br/>

~~~ C++
for (size_t i=0; i < v.size(); i++) {
    ...
}
~~~
or variations thereof.

This code is **ugly**.<br/>

- It uses the wrong type for indexing (see the argument below)
- It has a performance issue: it evaluates v.size() at every iteration
- It declares a variable (i) that is probably as good as unused
- It forces you to duplicate the information of the index type

There are a few clean ways to tackle this issue:
By decreasing order of preference (ymmv):

- use the appropriate algoritm:
  When you boil down a loop to its essentials, it is very likely to be duplicating a standard algorithm. Use the real thing instead!
- range `for_each`<br/>

~~~ C++
#include <boost/range/algorithm/for_each.hpp>
boost::for_each(v, [] (const auto& x) {
    ...
});
~~~
- range `for`<br/>

~~~ C++
for (const auto& x : v) {
    ...
}
~~~
- old style `for_each`<br/>

~~~ C++
#include <algorithm>
std::for_each(v.begin(), v.end(), [] (const auto& x) {
    ...
});
~~~
If we were to push the refactoring enough, all loops should be replaced with one of these forms. On new code, an old style for loop should be considered a code smell.

That being said, one has to be practical:
In a large ancient codebase, the amount of effort to make clean loops emerge from arcane cruft will probably be too costly.

Here are the guidelines I would advocate for:

- replace any trivial loop (where the index was only used for indexing in one array) with one of the above
- for the other ones, use consistent sane indexing

### Use consistent indexing

Before all: use a consistent index:
If you write this code consistently:

~~~ C++
for (int i = 0; i < v.size(); ++i) { // bad: sign-compare warning
    ...
}
~~~
you will end up with so many sign-compare warnings that you will not be practically able to gain any benefit from them.

As all warnings, sign-compare should be made to fail the build so that the compiler can save you from burning yourself alive when the occasional mistake happens.

### Use the right type

I took the following argument from [this stackoverflow thread](http://stackoverflow.com/questions/7488837/why-is-int-rather-than-unsigned-int-used-for-c-and-c-for-loops):

Using int is more correct from a logical point of view for indexing an array.

unsigned semantic in C and C++ doesn't really mean "not negative" but it's more like "bitmask" or "modulo integer".

To understand why unsigned is not a good type for a "non-negative" number please consider

- Adding an integer to a non-negative integer you get a non-negative integer
- The difference of two non-negative integers is always a non-negative integer
- Multiplying a non-negative integer by a negative integer you get a non-negative result

Obviously none of the above phrases make any sense... but it's how C and C++ unsigned semantic indeed works.

Actually using an unsigned type for the size of containers is a design mistake of C++ and unfortunately we're now doomed to use this wrong choice forever (for backward compatibility). You may like the name "unsigned" because it's similar to "non-negative" but the name is irrelevant and what counts is the semantic... and unsigned is very far from "non-negative".

(of course assuming the size of the vector is not changing during the iteration). This has the advantage of avoiding the traps that are a consequence of `unsigned` `size_t` design mistake. For example:

~~~ C++
// draw lines connecting the dots
for (size_t i = 0; i < pts.size() - 1; i++) {
    drawLine(pts[i], pts[i+1]);
}
~~~

the code above will have problems if the pts vector is empty because pts.size()-1 is a huge nonsense number in that case. Dealing with expressions where a < b-1 is not the same as a+1 < b even for commonly used values is like dancing in a minefield.

Historically the justification for having `size_t` unsigned is for being able to use the extra bit for the values, e.g. being able to have 65535 elements in arrays instead of just 32767 on 16-bit platforms. In my opinion even at that time the extra cost of this wrong semantic choice was not worth the gain (and if 32767 elements are not enough now then 65535 won't be enough for long anyway).

Unsigned values are great and very useful, but NOT for representing container size or for indexes; for size and index regular signed integers work much better because the semantic is what you would expect.

Unsigned values are the ideal type when you need the modulo arithmetic property or when you want to work at the bit level.

### Back to old-style for loops

So how do we deal with indexing in an old style for loop?

Based on the previous requirements, we could do:

~~~ C++
for (int i = 0; i < static_cast<int>(v.size()); i++) {
    ...
}
~~~
It uses the correct type and doesn't trigger warnings.

There are two issues with it though:

- It triggers undefined behaviour if v.size() is between the max signed and the max unsigned value
- It looks ugly and you wouldn't want to have this cluttering your code base

Here is an alternative, adapted from [this stack overflow thread](http://stackoverflow.com/questions/7443222/how-do-i-deal-with-signed-unsigned-mismatch-warnings-c4018):

Place this code in a "sane_size.h" header file:

~~~ C++
#include <cassert>
#include <cstddef>
#include <limits>
// When using int loop indices, use sane_size(container) instead of
// container.size() in order to document the inherent assumption that the size
// of the container can be represented by an int.
// If int is too small, use sane_size<int64_t>(container).
template <typename SaneSizeType = int, typename ContainerType>
constexpr SaneSizeType sane_size(const ContainerType &c) {
    const auto size = c.size();  // if no auto, use `typename ContainerType::size_type`
    assert(size <= static_cast<decltype(size)>(std::numeric_limits<SaneSizeType>::max()));
    return static_cast<SaneSizeType>(size);
}
~~~

You can now refactor your old crufty loops to look as follows:

~~~ C++
#include "sane_size.h"
for (int i = 0; i < sane_size(v); ++i) {
    ...
}
~~~

or for very large containers:

~~~ C++
for (int64_t i = 0; i < sane_size<int64_t>(v); ++i) {
    ...
}
~~~
