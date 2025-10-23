# Performance of "ML::SparseMatrixRecommender"

## Introduction

In this document we consider two performance topics for the package "ML::SparseMatrixRecommender", [AAp1]:

1. Recommender object creation
2. Recommendations computations

These are, of course, the most important performance topics. Resolving their slowness would most likely
involve profiling and implementations for all three packages: 
"ML::SparseMatrixRecommender", [AAp1], 
"Math::SparseMatrix", [AAp2], and 
"Math::SparseMatrix::Native", [AAp3]. 

## Recommender creation

Currently, version 0.0.3, recommender object creation is very slow for larger _long form_ data.
After some investigation and profiling it seems that most of slow-down comes from the 
method `impose-row-names` of `Math::SparseMatrix`, [AAp2]. 

**Remark:** Note that currently in [AAp2] methods like `impose-column-names` and `column-bind` are implemented
via `impose-row-names` and `row-bind`.

## Recommendations computations

Recommendations, both by history and by profile, use three steps:

1. Mapping of the history (profile) into a sparse matrix object
    - Denote with _spec-vector_.
2. Sparse linear algebra operations (dot product) with the spec-vector and the recommender matrix.
    - Denote with _rec-vector_.
3. Getting top-k elements from the rec-vector and forming the result.
    - The result can be a list of sorted pairs or a sparse matrix object.
    - Three parameters are acted upon in this step:
        - Taking of the top-K recommendations with the highest scores.
        - Removing the history from the recommendations.
            - When recommendation by history is computed.
        - Normalizing the scores.

**Remark:** Sparse vectors are represented as sparse matrix objects with one row or column.

Step 3 has a "vector result" alternative -- that is specified with the option `:vector-result`.
Vector results are formed via the method `Math::SparseMatrix.top-k-elements` which has 
an efficient implementation in "Math::SparseMatrix::Native".

**Remark:** Vector results of recommendation computations are useful as intermediate results for 
computations, like, classification by profile.

**Remark:** Vector results recommendations can be generalized into algorithms (class methods)
that do batch recommendations -- the argument is a list of profiles or matrix representing profiles.

Obviously, computational performance is influenced at all three steps above.
The most important and computationally intensive step (i.e. with most operations) is the second one,
but after making it fast -- by using native sparse linear algebra implementations -- the third step takes the most time.

Next, we discuss each step in turn.

### Making of a profile vector

### Sparse matrix computations

The package versions 0.0.3 or later use the fastest sparse matrix multiplications.
(Based on "Math::SparseMatrix::Native", [AAp2].)
Initially, I was not sure what is the best design. Here are my considerations:

- The "native" calculations should be switched on and off.
    - Useful for comparison, tracing, and testing purposes.
- Initially, it is not clear to me where the native computations should be specified/invoked. Two native switch on/off options:
    1. [ ] Should the native coercion be implemented at "Math::SparseMatrix" level?
        - I.e. if one of the multiplier is native the other is turned into native too.
    2. [X] Should "Math::SparseMatrixRecommender" decide on "native or not" depending on the matrices and a flag?
        - Using the second option proved to be easier to implement and test.

### Final result

The third step that forms the final result is the slowest.

#### History filtering

The recommendation vector filtering is currently too slow.
- Currently, sparse element-wise multiplication is used.
- There are several alternatives to _try out_ (and see which is faster.)

#### Top-K recommendations

For recommendations by profile using "the obvious route" of conversion of the result vector into a list of rules
and then taking the largest pairs is ≈11 times slower than the core dot-product computation.

Using the values and indexes of native object directly or via `Math::SparseMatrix::NativeAdapter` provides
faster computations. 

## References

[AAp1] Anton Antonov,
[ML::SparseMatrixRecommedner, Raku package](https://github.com/antononcube/Raku-ML-SparseMatrixRecommender),
(2025),
[GitHub/antononcube](https://github.com/antononcube).
([At raku.land](https://raku.land/zef:antononcube/ML::SparseMatrixRecommender)).

[AAp2] Anton Antonov,
[Math::SparseMatrix, Raku package](https://github.com/antononcube/Raku-Math-SparseMatrix),
(2024-2025),
[GitHub/antononcube](https://github.com/antononcube).
([At raku.land](https://raku.land/zef:antononcube/Math::SparseMatrix)).

[AAp3] Anton Antonov,
[Math::SparseMatrix::Native, Raku package](https://github.com/antononcube/Raku-Math-SparseMatrix-Native),
(2024-2025),
[GitHub/antononcube](https://github.com/antononcube).
([At raku.land](https://raku.land/zef:antononcube/Math::SparseMatrix::Native)).
