#import "@preview/polylux:0.3.1": *
#import "@preview/fletcher:0.3.0" as fletcher: node, edge
#import "theme/ctu.typ": *

#show: ctu-theme.with()

#title-slide[
    #set text(size: 1.3em)
  
    #v(6em)

    = Inside the Rust Borrow Checker
    
    Jakub Dupák
  

    #v(2em)

    #text(size: 0.7em)[
      \#lang-talk meetup
      
      19. 2. 2024
    ]
]

#slide[
  = Borrow Checker Rules

  #only("1-2")[
    - Move
  ]
  #only("3-")[#text(fill: luma(50%))[
    - Move
  ]]
  #only(2)[
    ```rust
      let mut v1 = Vec::new();
      v1.push(42)
      let mut v2 = v1; // <- Move
      println!(v1[0]); // <- Error
    
    ```
    #v(0.5em)
  ]
  #only("1-3")[
    - Lifetime subset relation
    - Borrow must outlive borrowee
  ]
  #only("4-")[#text(fill: luma(50%))[
    - Lifetime subset relation
    - Borrow must outlive borrowee
  ]]

    #only(3)[
     ```rust
      fn f() -> &i32 {
        &(1+1)
      } // <- Error
     ```
    #v(0.5em)
  ]
  - One mutable borrow or multiple immutable borrows
  - No modification of immutable borrow data
    #only(4)[
      ```rust
        let mut counter = 0;
        let ref1 = &mut counter;
        // ...
        let ref2 = &mut counter; //  <- Error
      ```
    ]
]

#slide[
  = Checking Functions

  #let f = ```rust
  struct Vec<'a> { ... }

  impl<'a> Vec<'a> {
    fn push<'b> where 'b: 'a (&mut self, x: &'b i32) {
      // ...
    }
  }
  ```

  #only("1")[#f]
  #only("2-")[
    #text(size: 0.7em, f)

    ```rust
    let a = 5;                     //  'a   'b   'b: 'a
    {                              //              
       let mut v = Vec::new();     //   *          
       v.push(&a);                 //   *    *     OK
       let x = v[0];               //   *    *     OK
     }                             //        *     OK
    ```
  ]

    #notes(
    ```md
    Protože analýza celého programu by měla extrémní výpočetní nároky, provádí borrow checker pouze analýzu uvnitř funkce.

    Na hranicích funkce musí programátor popsat popsat invarianty platnosti referencí a to pomocí lifetime anotací, na slidu apostrof `a` a apostrof `b`.

    Na příkladu zde máme vektor referencí, jejihž platnost v rámci programu je zdola omezena regionem apostrof `a`. Pokud chceme vložit fo vektoru novou referenci s platností apostrof `b`, musíme říci, že oblast programu apostrof `b` je alespoň tak velká, jako apostrof `a`.

    Zde na konrétním příkladu, můžete vidět dosazené časti programu.
    ```
  )
]

#title-slide[
  = Borrow checker evolution

  Lexical, NLL, Polonius
]

#slide[
  = Lexical borrow checker

  #only(1)[
    ```rust
      fn foo() {
        let mut data = vec!['a', 'b', 'c'];
        capitalize(&mut data[..]);         
        data.push('d');
        data.push('e');
        data.push('f');
      }
    ```
  ]
  
  #only(2)[
      ```rust
        fn foo() {
          let mut data = vec!['a', 'b', 'c']; // --+ 'scope
          capitalize(&mut data[..]);          //   |
          // ^~~~~~~~~~~~~~~~~~~~~~ 'lifetime //   |
          data.push('d');                     //   |
          data.push('e');                     //   |
          data.push('f');                     //   |
        } // <-------------------------------------+
      ```
  ]
]

#slide[
  = Lexical borrow checker

  ```rust
    fn bar() {
      let mut data = vec!['a', 'b', 'c'];
      let slice = &mut data[..]; // <-+ 'lifetime
      capitalize(slice);         //   |
      data.push('d'); // ERROR!  //   |
      data.push('e'); // ERROR!  //   |
      data.push('f'); // ERROR!  //   |
    } // <----------------------------+
  ```
]

#slide[
  = Lexical borrow checker

  ```rust
  fn process_or_default() {
    let mut map = ...;
    let key = ...;
    match map.get_mut(&key) { // -------------+ 'lifetime
        Some(value) => process(value),     // |
        None => {                          // |
            map.insert(key, V::default()); // |
            //  ^~~~~~ ERROR.              // |
        }                                  // |
    }; // <------------------------------------+
  }
  ```
]

#slide[
  = Non-lexical lifetimes (NLL)

    #align(center + horizon)[#text(size: 2em, weight: "bold", [
    lifetime = set of CFG nodes
  ])]
]

#slide[
  = Non-lexical lifetimes (NLL)


  #grid(columns: (3fr, 1fr))[
    ```rust
      fn f<'a>(map: &'r mut HashMap<K, V>) {
        ...
        match map.get_mut(&key) {
          Some(value) => process(value),
          None => {
            map.insert(key, V::default());
          }
        }
      }
    ```
  ][
    #set text(size: 0.75em, font: "Roboto Mono")

    #only(1)[
    #fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, "Start")
      node(match, "Match")
      node(s, "Some")
      node(n, "None")
      node(end, "End")
      node(ret, "Return")
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "->")
      edge(s, end, "->")
      edge(n, end, "->")
      edge(end, ret, "->")
    })]
    #only("2-")[
    #fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, "Start")
      node(match, text(fill:blue, "Match"))
      node(s, text(fill:green, "Some"))
      node(n, text(fill:red, "None"))
      node(end, text(fill:red, "End"))
      node(ret, "Return")
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "-->")
      edge(s, end, "-->")
      edge(n, end, "-->")
      edge(end, ret, "-->")
    })]
  ]

      #only(3)[
      === NLL #sym.arrow lifetimes are CFG nodes
    ]
]

#slide[
  = Breaking NLL
  
  #grid(columns: (3fr, 1fr))[
    #let c = ```rust
      fn f<'a>(map: &'a mut Map<K, V>) -> &'a V {
        ...
        match map.get_mut(&key) {
          Some(value) => process(value),
          None => {
            map.insert(key, V::default())
          }
        }
      }
    ```

    #only(1, code((1,8), c))
    #only(2, code((3,), c))
    #only(3, code((3,4), c))
    #only(4, code((3,4,8), c))
    #only(5, code((1,3,4,8,9), c))
    #only(6, code((5,6,7), c))
    #only(6)[ === Error! ]
  ][
    #set text(size: 0.75em, font: "Roboto Mono")

    #let cfg(step) = {
      fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, text(fill: if step >= 5 { red } else { black }, "Start"))
      node(match, text(fill: if step >= 2 { red } else { black }, "Match"))
      node(s, text(fill: if step >= 3 { red } else { black },"Some"))
      node(n, text(fill: if step >= 5 { red } else { black },
        weight: if step >= 6 { 900 } else { "regular" }
       ,"None"))
      node(end, text(fill: if step >= 4 { red } else { black}, "End"))
      node(ret, text(fill: if step >= 4 { red } else { black},"Return"))
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "->")
      edge(s, end, "->")
      edge(n, end, "->")
      edge(end, ret, "->")
    })}

    #for step in range(7) {
        only(step, cfg(step))
    }
  ]
]

#slide[
  = Polonius

  #align(center + horizon)[#text(size: 2em, weight: "bold", [
    Lifetime = set of loans
  ])]
]

#slide[
  = Polonius

    #grid(columns: (3fr, 1fr))[
    #let c = ```rust
      fn f<'a>(map: Map<K, V>) -> &'a V {
        ...
        match map.get_mut(&key) {
          Some(value) => process(value),
          None => {
            map.insert(key, V::default());
          }
        }
      }
    ```

    #only(1, code((5,6,7), c))
  ][
    #set text(size: 0.75em, font: "Roboto Mono")

    #let cfg(step) = {
      fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, text(fill: if step >= 5 { red } else { black}, "Start"))
      node(match, text(fill: if step >= 2 { red } else { black}, "Match"))
      node(s, text(fill: if step >= 3 { red } else { black},"Some"))
      node(n, text(fill: if step >= 5 { red } else { black},"None"))
      node(end, text(fill: if step >= 4 { red } else { black}, "End"))
      node(ret, text(fill: if step >= 4 { red } else { black},"Return"))
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "->")
      edge(s, end, "->")
      edge(n, end, "->")
      edge(end, ret, "->")
    })}

    #for step in range(2) {
        only(step, cfg(step))
    }
  ]
]

#slide[
  = Polonius

  ```rust
    let r: &'0 i32 = if (cond) {
      &x /* Loan L0 */
    } else {
      &y /* Loan L1 */
    };
  ```
]

#title-slide[
  = How does the program look?

  Internal representations
]

#slide[
  = Internal representations

  - AST = abstract syntax tree
  - HIR = high-level IR
  - Ty = type IR 
  - THIR = typed HIR
  - *MIR* = mid-level IR

  #v(2em)

  ```rust
    struct Foo(i31);
  
    fn foo(x: i31) -> Foo {
        Foo(x)
    }
  ```
]

#slide[
  = HIR

  ```
  Fn {
  generics: Generics { ... },
  sig: FnSig {
    header: FnHeader { ... },
    decl: FnDecl {
      inputs: [
        Param {
          ty: Ty { 
            Path { segments: [ PathSegment { 
                    ident: i32#0 } ] }
          }
          pat: Pat { Ident(x#0) }
        },
      ],
      output: Ty { Path { segments: [ PathSegment {
          ident: Foo#0 } ] }
  ```
]

#slide[
  = MIR

  ```
  fn foo(_1: i32) -> Foo {
      debug x => _1;
      let mut _0: Foo;
  
      bb0: {
          _0 = Foo(_1);
          return;
      }
  }
  ```
]

#slide[
  = MIR: Fibonacci

  #set text(size: 0.5em)

  #columns(2, gutter: 11pt)[

  ```
  fn fib(_2: u32) -> u32 {
    bb0: {
    0    StorageLive(_3);
    1    StorageLive(_5);
    2    _5 = _2;
    3    StorageLive(_6);
    4    _6 = Operator(move _5, const u32);
    5    switchInt(move _6) -> [bb1, bb2];
    }

    bb1: {
    0    _3 = const bool;
    1    goto -> bb3;
    }

    bb2: {
    0    StorageLive(_8);
    1    _8 = _2;
    2    StorageLive(_9);
    3    _9 = Operator(move _8, const u32);
    4    _3 = move _9;
    5    goto -> bb3;
    }

    bb3: {
    0    switchInt(move _3) -> [bb4, bb5];
    }

    bb4: {
    0    _1 = const u32;
    1    goto -> bb8;
    }

    bb5: {
    0    StorageLive(_14);
    1    _14 = _2;
    2    StorageLive(_15);
    3    _15 = Operator(move _14, const u32);
    4    StorageLive(_16);
    5    _16 = Call(fib)(move _15) -> [bb6];
    }

    bb6: {
    1    _19 = _2;
    3    _20 = Operator(move _19, const u32);
    5    _21 = Call(fib)(move _20) -> [bb7];
    }

    bb7: {
    0    _1 = Operator(move _16, move _21);
    7    goto -> bb8;
    }

    bb8: {
    5    return;
    }
}
  ```]
]

#title-slide[
  = Computing!

  Steps of the borrow checker
]

#slide[
  = What do we need?

  #only(1)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 100%))) ]
  #only(2)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(3)[ #box(width: 100%, height: 100%, clip: true, inset: (top: -50%, bottom: 50%), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(4)[ #box(width: 100%, height: 100%, clip: true, inset: (top: -100%, bottom: 100%), align(center, image("media/polonius.svg", height: 200%))) ]
  #only(5)[ #box(width: 100%, height: 100%, clip: true, inset: (top: 0pt), align(center, image("media/polonius.svg", height: 100%))) ]
]

#title-slide[
  = What about lifetime annotations?

  ```rust
  let x: &'a i32;
  ```
]

#slide[
  = Lifetime annotations everywhere

  #only(1, ```rust
    fn max_ref(a: &i32, b: &i32) -> &i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```)
  #only(2, code((1,),```rust
    fn max_ref(a: &'a i32, b: &'a i32) -> &'a i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(3, code((1,),```rust
    fn max_ref(a: &'a i32, b: &'b i32) -> &'c i32 {
      let mut max = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(4, code((2,),```rust
    fn max_ref(a: &'a i32, b: &'b i32) -> &'c i32 {
      let mut max: &i32 = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```))
  #only(5, {
    code((2,3,4,5,5,6),```rust
    fn max_ref(a: &'a i32, b: &'b i32) -> &'c i32 {
      let mut max: &'?1 i32 = a;
      if (*max < *b) {
        max = b;
      }
      max
    }
  ```)
  set align(horizon + center)
  set text(size: 1.5em, )
  table(columns: 2, column-gutter: 50pt, row-gutter: 10pt,  stroke: none, 
    [`max = a`],[ `'a: '?1` ],
    [`max = b`], [ `'b: '?1` ],
    [`return max`], [ `'?1: 'c` ],
  )
})
]

#slide[
    #only(1)[ #box(width: 100%, height: 100%, clip: true, inset: (top: -50%, bottom: 50%), align(center, image("media/polonius.svg", height: 200%))) ]

]

#title-slide[
  = Is it that simple?

  `Customer<'&a, Vec<(Box<dyn Dealer>, &'b mut i32)>>`
]

#slide[
  = Variance

  #set align(center + horizon)

  ```rust
  struct T<'a> {
    a: &'a i32,
    f: fn(&'a i32),
  }
  ```
  
  $T angle.l 'a angle.r subset.eq T angle.l 'b angle.r$
  
  $'a lt quest gt 'b$
]

#slide[
  = Variance

  #set align(center + horizon)

  #fletcher.diagram({
    let (b,co,ct, i) = ((0,0), (-1,-1), (1,-1), (0, -2));
    node(b, "bivariant")
    node(co, "covariant")
    node(ct, "contravariant")
    node(i, "invariant")
    edge(b, co, "->")
    edge(b, ct, "->")
    edge(co, i, "->")
    edge(ct, i, "->")
  })
]

#slide[
  = Example: Variance Computation

  ```rust
    struct Foo<'a, 'b, T> {
       x: &'a T,
       y: Bar<T>,
    }
  ```

  #v(2em)

  #only(1)[
    - *Collect variance info*
      - $f_0=o$, $f_1=o$, $f_2=o$
      - `x` in the covariant position: 
        - `&'a T` in the covariant position: $f_0=+$ and $f_2=+$
      - `y` in the covariant position:
        - $f_2 = "join"(f_2, "transform"(+, b_0))$
  ]

  #only(2)[
   - *Iteration 1*:
     -   $f_0=+$, $f_1=o$, $f_2=+$.
     -   $"transform"(+, b_0) = -$
     -   $"join"(*, -) = *$
  ]

  #only(3)[
   - *Iteration 2*:
     -   $f_0=+$, $f_1=o$, $f_2=*$.
     -   $"transform"(+, b_0) = -$
     -   $"join"(*, -) = *$
  ]

  #only(4)[
    - Final variances: $f_0=+$, $f_1=o$, $f_2=*$:
    
      -  f0 is evident.
      -  f1 remains bivariant, as it is not mentioned in the type.
      -  f2 is invariant due to its usage in both covariant and contravariant positions.
  ]
]

#slide[
  = Why is it useful?

  ```rust
    fn main() {
       let s = String::new();
       let x: &'static str = "hello world";
       let mut y = &*s;
       y = x;
    }
  ```
]

#slide[
  = Example: Variance in rustc

  #let c = ```rust
  fn write_scope_tree(
    tcx: TyCtxt<'_>,
    body: &Body<'_>,
    scope_tree: &FxHashMap<...>,
    w: &mut dyn io::Write,
    parent: SourceScope,
    depth: usize,
  ) -> io::Result<()> { ... }
  ```

  #let c2 = ```rust
  fn write_scope_tree<'a>(
    tcx: TyCtxt<'a>,
    body: &Body<'a>,
    scope_tree: &FxHashMap<...>,
    w: &mut dyn io::Write,
    parent: SourceScope,
    depth: usize,
  ) -> io::Result<()> { ... }
  ```

  #only(1, code((1,2,3,4,5,6,7,8,9), c))
  #only(2, code((), c))
  #only(3, code((1,2,3), c2))


  #only(2)[
    ```rust
    if let ty::Adt(_, _) = local_decl.ty.kind() {
        display_adt(tcx, &mut indented_decl, local_decl.ty);
    }
    ```
    ```rust
    pub fn display_adt<'tcx>(tcx: TyCtxt<'tcx>, w: &mut String, ty: Ty<'tcx>) {...}
    ```
  ]
]

#title-slide[
  = But how?

  Dataflow, datalog, Polonius
]

#slide[
  = Dataflow

  #grid(columns: (3fr, 2fr))[
      - Semilattice
      - State
        - IN
        - OUT
      - Transform function
      - Iteration
      
  ][
      #fletcher.diagram(
      {
      let (start, match, s, n, end, ret) = ((0,0), (0,-1), (-0.5, -2), (0.5, -2), (0, -3), (0, -4))
      node(start, "Start")
      node(match, "Match")
      node(s, "Some")
      node(n, "None")
      node(end, "End")
      node(ret, "Return")
      edge(start, match, "->")
      edge(match, s, "->")
      edge(match, n, "->")
      edge(s, end, "->")
      edge(n, end, "->")
      edge(end, ret, "->")
    })
  ]
]

#slide[
  = Datalog Polonius

  #set text(size: .95em)

  ```
  origin_contains_loan_on_entry(Origin, Loan, Point) :-
    loan_issued_at(Origin, Loan, Point).
  
  origin_contains_loan_on_entry(Origin2, Loan, Point) :-
    origin_contains_loan_on_entry(Origin1, Loan, Point),
    subset(Origin1, Origin2, Point).
  
  origin_contains_loan_on_entry(Origin, Loan, TargetPoint) :-
    origin_contains_loan_on_entry(Origin, Loan, SourcePoint),
    !loan_killed_at(Loan, SourcePoint),
    cfg_edge(SourcePoint, TargetPoint),
    (origin_live_on_entry(Origin, TargetPoint); placeholder(Origin, _)).
  ```
]

#title-slide[
  #image("media/gccrs.png", height: 7em)
  #v(-3em)
  = Bonus: Rust GCC
]

#slide[
  = Rust GCC

  #set align(center+horizon)
  #image("media/pipeline.svg")
]

#slide[
  = Rust GCC

  #set align(center+horizon)
  #image("media/bir.svg")
]

#slide[
  = References

  #set text(size: 0.7em)
  
  - MATSAKIS, Niko. 2094-nll. In : The Rust RFC Book. Online. Rust Foundation, 2017. [Accessed 18 December 2023]. Available from https: rust-lang.github.io/rfcs/2094-nll.html
  - STJERNA, Amanda. Modelling Rust’s Reference Ownership Analysis Declaratively in Datalog. Online. Master’s thesis. Uppsala University, 2020. [Accessed 28 December 2023]. Available from: https://www.diva-portal.org/smash/get/diva2:1684081/fulltext01.pdf
  - MATSAKIS, Niko, RAKIC, Rémy and OTHERS. The Polonius Book. 2021. Rust Foundation.
  - GJENGSET, Jon.  Crust of Rust: Subtyping and Variance. 2022. [Accessed 19 February 2024]. Available from https://www.youtube.com/watch?v=iVYWDIW71jk
  - Rust Compiler Development Guide. Online. Rust Foundation, 2023. [Accessed 18 December 2023]. Available from https://rustc-dev-guide.rust-lang.org/index.html
  - TOLVA, Karen Rustad. Original Ferris.svg. Available from https://en.wikipedia.org/wiki/File:Original_Ferris.svg
]

#title-slide[
  #move(dy: 6em,image("media/ferris-happy.svg", height: 40%))
  #v(3em)
  #text(size: 3em, weight: 800)[That's all Folks!]
]