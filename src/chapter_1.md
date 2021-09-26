# Peano

Rust's type system is quite powerful as it allows to encode complex relationships between user-defined types using recursive rules that are automatically applied by the compiler. Idea behind this post is to use some of those rules to encode properties of our domain. Here we take a look at [Peano](https://en.wikipedia.org/wiki/Peano_axioms) axioms defined for natural numbers and try to derive some of them using traits, trait bounds and recursive impl blocks. We want to make the compiler work for us by verifying facts about our domain, so that we could invoke the compiler to check whether a particular statement holds or not. Our end goal is to encode natural numbers as types and their relationships as traits such that only valid relationships would compile. (e.g. in case we define types for 1 and 3 and relationship of less than, 1 < 3 should compile but 3 < 1 shouldn't, that all would be encoded using Rust's language syntax of course)

Let's define some natural numbers on the type level first.

```rust
struct _0;
struct Succ<T>(T);
```

Here we use structs to define elements of the natural set. We can start with `_0` and use the type constructor `Succ` to create types for each natural number. `Succ` here is short for successor and we encode `Succ<N>` as successor of `N`, the natural number that goes straight after `N`.

Important note is that each element is represented by the type itself, not a value of that type, we don't plan to instantiate any values here.

We have to manually construct 1, 2, 3, ... at this point. It should be possible to workaround that but we won't get into those details just yet.

```rust
# struct _0;
# struct Succ<T>(T);
type _1 = Succ<_0>;
type _2 = Succ<_1>;
type _3 = Succ<_2>;
type _4 = Succ<_3>;
type _5 = Succ<_4>;
```

Now we have types for 1, 2, 3, 4 and 5 but they are hardly useful on their own as they are just labels without any meaning attached.

Let's now define the first property that must hold, which is that all of those numbers are natural numbers. We will use the trait `Nat` for this task.

```rust
# struct _0;
# struct Succ<T>(T);
trait Nat {}
```

Then we implement this trait for types we have just defined using `impl` blocks.

```rust
# struct _0;
# struct Succ<T>(T);
# trait Nat {}
impl Nat for _0 {}
impl<T: Nat> Nat for Succ<T> {}
```

Notice here the second `impl` block is taking parameter `T` and is implementing `Nat` for the successor of that type. This is essentially encoding the property that natural numbers are closed with respect to addition, if you keep adding one to the natural number you still get a natural number.

We've encoded some rules but how do we actually check them? Let's use type bounds and helper functions for that.

First define a function to test whether all number types we have defined are indeed natural (implement `Nat`)

```rust
# trait Nat {}
# struct Succ<T: Nat>(T);
# struct _0;
# impl Nat for _0 {}
# impl<T: Nat> Nat for Succ<T> {}
# type _1 = Succ<_0>;
# type _2 = Succ<_1>;
# type _3 = Succ<_2>;
fn test_is_nat<T: Nat>() -> () {}

fn main() {
   test_is_nat::<_0>();
   test_is_nat::<_1>();
   test_is_nat::<_2>();
   // ...
}
```

Notice that the function is empty as we are only interested in types of our program.

Now this compiles, which means our property holds. That's great but hardly that interesting.

Let's define a trait `Lt` that would take two type parameters `A` and `B`. The meaning of this trait would be the relationship between types `A` and `B`, that is `A < B` in terms of natural numbers.

In this post we will only consider less than (`<`) but deriving various other laws should be similar.

```rust
# trait Nat {}
trait Lt<A: Nat, B: Nat> {}
```

Let's try to derive laws for `Lt` using what we have defined so far. To formalize it using induction we can take following approach:

- `0` is less than any natural number, this is going to be base case of induction
- for any `A` and `B`, such that `A` is less than `B` we can state that `Succ<A>` is less than `Succ<B>` (if we add one to both sides of valid inequality, the inequality should still hold)

However before we define those rules using `impl` blocks as we did for `Nat` traits we need to define another additional type. When describing whether type is a natural number we used that particular type as a target to implement trait `Nat` (what goes after `for` in `impl` definition). In case of `Lt` relationship however we need to capture both types into that target type so let's create another struct and call it `ProofLt`, naming choice would make more sense later.

```rust
# trait Nat {}
struct ProofLt<A: Nat, B: Nat>(A, B);
```

Another auxiliary bit we need here is the `NonZero` trait that would represent any natural number except for zero, we will need it to encode a base case for our induction.

```rust
# trait Nat {}
// we also need to amend our `Succ` definition to make it work
struct Succ<T: Nat>(T);
# impl<T: Nat> Nat for Succ<T> {}
trait NonZero: Nat {}
impl<N: Nat> NonZero for Succ<N> {}
```

We include only natural numbers that are produced by applying `Succ` type constructor, thus excluding `_0`.

Now let's use `ProofLt` as a target type to define less than relationship.

Encoding the base case is straightforward: we literally translate the rule, for any `N` that is not a zero, `_0` is less than that `N`.

```rust
# trait Nat {}
# struct Succ<T: Nat>(T);
# struct _0;
# impl Nat for _0 {}
# impl<T: Nat> Nat for Succ<T> {}
# trait Lt<A: Nat, B: Nat> {}
# trait NonZero: Nat {}
# impl<N: Nat> NonZero for Succ<N> {}
# struct ProofLt<A: Nat, B: Nat>(A, B);
impl<N: NonZero> Lt<_0, N> for ProofLt<_0, N> {}
```

The key to encoding the induction step is to restrict recursive rule by adding `where` clause with constraint.

```rust
# trait Nat {}
# struct Succ<T: Nat>(T);
# struct _0;
# impl Nat for _0 {}
# impl<T: Nat> Nat for Succ<T> {}
# trait Lt<A: Nat, B: Nat> {}
# struct ProofLt<A: Nat, B: Nat>(A, B);
impl<A: Nat, B: Nat> Lt<Succ<A>, Succ<B>> for ProofLt<Succ<A>, Succ<B>>
   where ProofLt<A, B>: Lt<A, B> {}
```

Here we only implement `Lt` for successors of `A` and `B` if property is less than held for `A` and `B` themselves.

As this rule is applied recursively, this is just enough for us to encode `Lt` for any two natural numbers. Compiler will do the heavy lifting for us here by recursively unwinding type definitions of types in questions until it hits the base case.

Now to check whether `<` is holding for some types `A` and `B` we could use our `ProofLt` struct to summon `Lt` trait implementations, but in order to do this we need to define some method on the `Lt` trait we could call. In case a method is found and compilation succeeds we can conclude that `Lt` is implemented for that pair for types, thus `<` property holds, otherwise it doesn't.

Let's amend our `Lt` definition with this extra function.

```rust
# trait Nat {}
trait Lt<A: Nat, B: Nat> {
   fn check() -> () {}
}
```

Semantically this function would mean that `Lt` property is holding and we should only be able to call this function on our target type `ProofLt` in case `Lt` indeed holds. Otherwise the compiler should yell at us failing to find function definition. Again we are not really interested in calling this function (thus empty body and argument list), but whether it is there or not.

```rust
# trait Nat {}
# struct Succ<T: Nat>(T);
# struct _0;
# impl Nat for _0 {}
# impl<T: Nat> Nat for Succ<T> {}
# type _1 = Succ<_0>;
# type _2 = Succ<_1>;
# type _3 = Succ<_2>;
# trait Lt<A: Nat, B: Nat> {
#     fn check() -> () {}
# }
# trait NonZero: Nat {}
# impl<N: Nat> NonZero for Succ<N> {}
# struct ProofLt<A: Nat, B: Nat>(A, B);
# impl<N: NonZero> Lt<_0, N> for ProofLt<_0, N> {}
# impl<A: Nat, B: Nat> Lt<Succ<A>, Succ<B>> for ProofLt<Succ<A>, Succ<B>>
#     where ProofLt<A, B>: Lt<A, B> {}

fn main() {
   // this is actually only using our base case of induction
   ProofLt::<_0, _1>::check();
   // now the real test
   ProofLt::<_1, _3>::check();
}
```

Yay, it works! Now let's try to check whether it indeed rejects invalid examples.

```rust
# trait Nat {}
# struct Succ<T: Nat>(T);
# struct _0;
# impl Nat for _0 {}
# impl<T: Nat> Nat for Succ<T> {}
# type _1 = Succ<_0>;
# type _2 = Succ<_1>;
# type _3 = Succ<_2>;
# trait Lt<A: Nat, B: Nat> {
#     fn check() -> () {}
# }
# trait NonZero: Nat {}
# impl<N: Nat> NonZero for Succ<N> {}
# struct ProofLt<A: Nat, B: Nat>(A, B);
# impl<N: NonZero> Lt<_0, N> for ProofLt<_0, N> {}
# impl<A: Nat, B: Nat> Lt<Succ<A>, Succ<B>> for ProofLt<Succ<A>, Succ<B>>
#     where ProofLt<A, B>: Lt<A, B> {}

fn main() {
   ProofLt::<_3, _2>::check();
}
```

If we try to compile above code, the compiler would yell at us with something like
 
```
//    | struct ProofLt<A: Nat, B: Nat>(A, B);
//    | -------------------------------------
//    | |
//    | function or associated item `check` not found for this
//    | doesn't satisfy `_: Lt<Succ<Succ<Succ<_0>>>, Succ<Succ<_0>>>`
//    | doesn't satisfy `_: Lt<Succ<Succ<_0>>, Succ<_0>>`
```

It failed to find the associated function `check` because trait `Lt` is not implemented for this variant of `ProofLt`.

And this is exactly what we wanted to encode!

You can play around more with `ProofLt` and try to define new natural numbers.

```rust,editable
trait Nat {}
struct Succ<T: Nat>(T);

struct _0;
impl Nat for _0 {}
impl<T: Nat> Nat for Succ<T> {}

type _1 = Succ<_0>;
type _2 = Succ<_1>;
type _3 = Succ<_2>;

trait Lt<A: Nat, B: Nat> {
   fn check() -> () {}
}

trait NonZero: Nat {}
impl<N: Nat> NonZero for Succ<N> {}

struct ProofLt<A: Nat, B: Nat>(A, B);
impl<N: NonZero> Lt<_0, N> for ProofLt<_0, N> {}
impl<A: Nat, B: Nat> Lt<Succ<A>, Succ<B>> for ProofLt<Succ<A>, Succ<B>>
   where ProofLt<A, B>: Lt<A, B> {}

fn main () {
   ProofLt::<_2, _3>::check()
   // this will fail
   // ProofLt::<_2, _2>::check()
   // ProofLt::<_0, _0>::check()
}
```

There's also a link to Rust Playground to get a feel for it.

[https://play.rust-lang.org/](https://play.rust-lang.org/?version=stable&mode=debug&edition=2018&gist=ba70a21d8fba30ca417674d873e12428)

Now this is all obscure and abstract, but it is actually very powerful concept that can help us define properties from our domain in software and ensure that those properties hold using the compiler itself for verification.

This work was very much inspired by similar feature set of Scala that is using implicits as facts that can be derived on other types, if you are curious to learn more check out this video by Rock The Jvm touching on a subject

[https://www.youtube.com/watch?v=qwUYqv6lKtQ](https://www.youtube.com/watch?v=qwUYqv6lKtQ)
