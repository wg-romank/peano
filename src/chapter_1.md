# Peano

Let's define some natural numbers on the type level first. We can start with 0 and use type constructor to create types of each element.

```rust
struct _0;
struct Succ<T>(T);
```

We have to manually construct 1, 2, 3, ... at this point. It should be possible to workaround that using procedurial macro but we won't get into those details just yet.

```rust
# struct _0;
# struct Succ<T>(T);
type _1 = Succ<_0>;
type _2 = Succ<_1>;
type _3 = Succ<_2>;
type _4 = Succ<_3>;
type _5 = Succ<_4>;
```

Since we will be defining some laws that are applicable to types we have just defined it is handy to define a trait to represent all of them.

```rust
# struct _0;
# struct Succ<T>(T);
trait Nat {}
impl Nat for _0 {}
impl<T: Nat> Nat for Succ<T> {}
```

Now we are ready to define some of the properties those types should follow. In this post we will only consider less than (`<`) but deriving various other laws should be analogous.

Let's define a trait `Lt` that would take two type parameters `A` and `B`. Semantic meaning of this trait would be relationship between types `A` and `B`, that is `A < B` in terms of natural numbers.

```rust
# trait Nat {}
trait Lt<A: Nat, B: Nat> {}
```

Let's try to define laws that natural numbers follows in terms of these types in Rust notation. We will formalize it using induction:

- `0` is less than any natural number, this is going to be base case of induction
- for any `A` and `B`, such that `A` is less than `B` we can state that `Succ<A>` is less than `Succ<B>`

However before we define those rules using `impl` blocks as we dit for `Nat` trait we need to define additional type. When describing whether type is a natural number we used that particular type as a target to implement trait `Nat` for. In case of `Lt` relationship however we need to capture both types into that target type so let's create another struct and call it `ProofLt`, naming choice would more sense later.

```rust
# trait Nat {}
struct ProofLt<A: Nat, B: Nat>(A, B);
```

Another auxillary bit we need here is `NonZero` trait that would represent any natural number except for zero, we will need it to encode a base case for our induction.

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

Encoding base case is straightforward we literally translate the rule, for any `N` that is not a zero, `_0` is less than that `N`.

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

The key to encoding induction step is to restrict recursive rule by adding `where` clause with constraint.

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

We've encoded some rules but how do we actually check them? Let's use type bounds and helper methods for that.

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

Now to check whether `<` is holding for some types `A` and `B` we could use our `ProofLt` struct to summon `Lt` trait implementations, but in order to do this we need to define some method on `Lt` trait we could call. In case method is found and compilation succeds we can conclude that `<` property holds, otherwise it doesn't.

Let's amend our `Lt` definition with this extra function.

```rust
# trait Nat {}
trait Lt<A: Nat, B: Nat> {
    fn check() -> () {}
}
```

Semantially this function would mean that `Lt` property is holding and we should only be able to call this function on our target type `ProofLt` in case `Lt` indeed holds. Otherwise compiler should yell at us failing to find function definiton. Again we are not really interested in calling this function (thus empty body and argument lits), but whether it is there or not.

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

It failed to find associated function `check` because trait `Lt` is not implemented for this varian of `ProofLt`.

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

There's a link to Rust Playground to get a feel for it.

[https://play.rust-lang.org/](https://play.rust-lang.org/?version=stable&mode=debug&edition=2018&gist=ba70a21d8fba30ca417674d873e12428)

This work was very much inspired by similar feature set of Scala that is using implicits as facts that can be derived on other types, if you are curious to learn more checke out this video by Rock The Jvm touching on a subject

[https://www.youtube.com/watch?v=qwUYqv6lKtQ](https://www.youtube.com/watch?v=qwUYqv6lKtQ)