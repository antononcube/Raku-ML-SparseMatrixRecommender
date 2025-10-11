use v6;

use Math::SparseMatrix;
use ML::SparseMatrixRecommender::DocumentTermWeightish;

## Monadic-like definition.
class ML::SparseMatrixRecommender
        does ML::SparseMatrixRecommender::DocumentTermWeightish {

    ##========================================================
    ## Data members
    ##========================================================
    has %!matrices = %();
    has $!M = Whatever;
    has %!tag-type-weights = %();
    has $!data = Whatever;
    has $!value = Whatever;

    ##========================================================
    ## Performance
    ##========================================================
    has %!items = %();
    has %!tags = %();

    method !file-in-items-and-tags() {
        %!items = $!M.row-names Z=> (^$!M.nrow);
        %!tags = $!M.column-names Z=> (^$!M.ncol);
    }

    method to-profile-vector(
            Mix:D $mix,
            Bool:D :$column = True,
            Str:D :$item-name = 'profile',
            Bool:D :$warn = False
                               ) {
        # Make sure the items and tags are current
        self!file-in-items-and-tags if %!items.elems == 0 || %!tags.elems == 0 || %!items.elems != $!M.nrow || %!tags.elems != $!M.ncol;

        # Make the rules
        my @rules = $mix.map({ %!tags{$_.key}:exists ?? ((%!tags{$_.key}, 0) => $_.value) !! Empty });

        if $warn {
            note 'None of the keys of the argument are known tags.' if @rules.elems == 0;
            note 'Some of the keys of the argument are not known tags.' if 0 < @rules.elems < $mix.elems;
        }

        # Make the column matrix
        my $mat = Math::SparseMatrix.new(
                    :@rules,
                    nrow => $!M.ncol,
                    ncol => 1,
                    row-names => $!M.column-names,
                    column-names => [$item-name, ]);

        if !$column { $mat .= transpose }

        return $mat;
    }

    method to-history-vector(
            Mix:D $mix,
            Bool:D :$column = False,
            Str:D :$tag-name = 'history',
            Bool:D :$warn = False
                               ) {
        # Make sure the items and tags are current
        self!file-in-items-and-tags if %!items.elems == 0 || %!tags.elems == 0 || %!items.elems != $!M.nrow || %!tags.elems != $!M.ncol;

        # Make the rules
        my @rules = $mix.map({ %!items{$_.key}:exists ?? ((%!items{$_.key}, 0) => $_.value) !! Empty });

        if $warn {
            note 'None of the keys of the argument are known items.' if @rules.elems == 0;
            note 'Some of the keys of the argument are not known items.' if 0 < @rules.elems < $mix.elems;
        }

        # Make the row matrix
        my $mat = Math::SparseMatrix.new(
                :@rules,
                nrow => 1,
                ncol => $!M.nrow,
                row-names => [$tag-name, ],
                column-names => $!M.row-names,
                );

        if $column { $mat .= transpose }

        return $mat;
    }

    ##========================================================
    ## Setters
    ##========================================================
    method set-smr-matrix($m) {
        return self.set-M($m);
    }

    #| Set recommendation matrix.
    method set-M($arg) {
        die "The first argument is expected to be a Math::SparseMatrix object."
        unless $arg ~~ Math::SparseMatrix:D;
        $!M = $arg.clone;
        self!file-in-items-and-tags;
        return self;
    }

    #| Set recommendation sub-matrices.
    method set-matrices($arg) {
        die "The first argument is expected to be a hashmap of Math::SparseMatrix objects."
        unless $arg ~~ Map:D && $arg.values.all ~~ Math::SparseMatrix:D;
        %!matrices = $arg;
        return self;
    }

    #| Set the tag type weights.
    method set-tag-type-weights($arg) {
        die "The first argument is expected to be a hashmap of strings to numbers."
        unless $arg ~~ Map:D && $arg.values.all ~~ Numeric:D;
        %!tag-type-weights = $arg;
        return self;
    }

    #| Set data.
    method set-data($arg) {
        $!data = $arg;
        return self;
    }

    #| Set pipeline value.
    method set-value($arg) {
        $!value = $arg;
        return self;
    }

    ##========================================================
    ## Takers
    ##========================================================
    #| Take the tag type matrices
    method take-matrices() { %!matrices }

    #| Take the recommender matrix
    method take-smr-matrix() { $!M}

    #| Take the recommender matrix
    method take-M() { $!M }

    #| Take tag type weights
    method take-tag-type-weights(-->Map:D) {
        %!tag-type-weights
    }

    #| Take the data
    method take-data() {
        $!data
    }

    #| Take the pipeline value.
    method take-value() {
        $!value
    }

    #| Take sub-matrix corresponding to the argument.
    method sub-matrix(Str:D $tag-type) {
        die "The tag type $tag-type is not known in the recommender."
        unless self.take-matrices{$tag-type}:exists;
        self.take-matrices{$tag-type}
    }

    ##========================================================
    ## Echoers
    ##========================================================
    method echo-M(:&with = &say) {
        &with($!M);
        self
    }

    method echo-matrices(:&with = &say) {
        &with(%!matrices);
        self
    }

    method echo-tag-type-weights(:&with = &say) {
        &with(%!tag-type-weights);
        self
    }

    method echo-data(:&with = &say) {
        &with($!data);
        self
    }

    multi method echo-value(Str:D $note, :&with = &say, :&as = WhateverCode) {
        return self.echo-value(:$note, :&with, :&as);
    }

    multi method echo-value(Str:D :$note = '', :&with = &say, :&as = WhateverCode) {
        &as.defined ?? &with($note, &as($!value)) !! &with($note, $!value);
        self
    }

    ##========================================================
    ## BUILD
    ##========================================================
    submethod BUILD(:$!M = Whatever, :%!matrices = %(), :%!tag-type-weights = %(), :$!data = Whatever, :$!value = Whatever) {
    }

    multi method new(:$M = Whatever, :%matrices = %(), :%tag-type-weights = %(), :$data = Whatever, :$value = Whatever) {
        self.bless(:$M, :%matrices, :%tag-type-weights, :$data, :$value);
    }

    multi method new($matrices, :$value = Whatever) {
        die 'The first argument is expected to be a hashmap of Math::SparseMatrix objects.'
        unless $matrices ~~ Map:D && $matrices.values.all ~~ Math::SparseMatrix:D;
        my $M = reduce({$^a.column-bind($^b)}, |$matrices.values);
        self.bless(:$M, :$matrices, :$value);
    }

    ##========================================================
    ## Clone
    ##========================================================
    method clone(::?CLASS:D: --> ::?CLASS:D) {
        return ML::SparseMatrixRecommender.new(:$!M, :%!matrices, :%!tag-type-weights, :$!data, :$!value);
    }

    ##========================================================
    ## Creation methods
    ##========================================================
    method create-item-tag-matrix(
            @data where @data.all ~~ Map:D,
            Str:D $item-key,
            Str:D $tag-key,
            Bool:D :$add-tag-types-to-column-names = True,
            Str:D :$tag-value-separator = ':'
            --> Math::SparseMatrix:D) {
        my @edge-dataset =
                do if $add-tag-types-to-column-names {
                    @data.map({ %( :from($_{$item-key}), :to($tag-key ~ $tag-value-separator ~ $_{$tag-key}), :weight(1) ) })
                } else {
                    @data.map({ %( :from($_{$item-key}), :to($_{$tag-key}), :weight(1) ) })
                }
        return Math::SparseMatrix.new(:@edge-dataset):directed;
    }

    method create-from-wide-form(
            @data where @data.all ~~ Map:D,
            :$tag-types is copy = Whatever,
            :item-column-name(:$item-key) is copy = Whatever,
            Bool:D :$add-tag-types-to-column-names = True,
            Str:D :$tag-value-separator = ':',
            *%extra) {
        if $item-key.isa(Whatever) {
            $item-key = @data.head.keys.first({ $_ ~~ /:i id/ });
            die 'Cannot automatically deduces the item column name (item-key)'
            unless $item-key.defined;
        }

        if $tag-types.isa(Whatever) {
            $tag-types = @data.head.keys.grep({$_ ne $item-key}).List
        }

        die 'The argument $tag-types is expected to be a list of strings or Whatever.'
        unless $tag-types ~~ (Array:D | List:D | Seq:D) && $tag-types.all ~~ Str:D;

        $tag-types .= grep({$_ ne $item-key});
        my %matrices = |$tag-types.map(-> $type {
            $type => self.create-item-tag-matrix(@data, $item-key, $type, :$add-tag-types-to-column-names, :$tag-value-separator)
        });

        return self.create-from-matrices(%matrices, |%extra);
    }

    method create-from-matrices(
            $matrices,
            Bool:D :$add-tag-types-to-column-names = True,
            Bool:D :$numerical-columns-as-categorical = False,
            Str:D :sep(:$tag-value-separator) = ':') {

        die 'The first argument is expected to be a hashmap of Math::SparseMatrix objects.'
        unless $matrices ~~ Map:D && $matrices.values.all ~~ Math::SparseMatrix:D;

        my @rowNames = $matrices.values.map(*.row-names);

        # Check if the row names of the matrices are the same
        if !reduce(&infix:<eqv>, @rowNames».sort».List) {
            @rowNames = $matrices.map(*.row-names).flat.unique.sort;
            %!matrices = $matrices.map({ $_.impose-rows(@rowNames) })
        } else {
            %!matrices = |$matrices
        }
        %!tag-type-weights = %!matrices.keys X=> 1;

        # Make the recommender matrix
        $!M = reduce({$^a.column-bind($^b)}, %!matrices.values);
        self!file-in-items-and-tags;

        return self;
    }


    ##========================================================
    ## Apply LSI functions
    ##========================================================
    #| Apply LSI functions to the entries of the recommendation matrix.
    multi method apply-term-weight-functions(
            :global(:$global-weight-func) = Whatever, #= LSI global term weight function. One of "ColumnSum", "Entropy", "IDF", "None".
            :local(:$local-weight-func)  = Whatever,  #= LSI local term weight function. One of "Binary", "Log", "None".
            :normalizer(:$normalizer-func) = Whatever    #= LSI normalizer function. One of "Cosine", "None", "RowSum".
                                             ) {
        return self.apply-term-weight-functions($global-weight-func, $local-weight-func, $normalizer-func);
    }

    multi method apply-term-weight-functions(
            $global-weight-func is copy = Whatever, #= LSI global term weight function. One of "ColumnSum", "Entropy", "IDF", "None".
            $local-weight-func is copy = Whatever,  #= LSI local term weight function. One of "Binary", "Log", "None".
            $normalizer-func is copy = Whatever     #= LSI normalizer function. One of "Cosine", "None", "RowSum".
                                             ) {
        %!matrices = %!matrices.kv.map(-> $k, $m {
            $k => self.apply-lsi-weight-functions($m, $global-weight-func, $local-weight-func, $normalizer-func)
        });

        # Make the recommender matrix
        $!M = reduce({$^a.column-bind($^b)}, %!matrices.values);
        self!file-in-items-and-tags;
        return self;
    }

    ##========================================================
    ## Profile
    ##========================================================
    #| Find items profile.
    #| * C<$items> A list of items, a hashmap or mix of scored items, or 1-row Math::SparseMatrix object.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$warn> Should warnings be issued or not?
    method profile($items is copy,
                   Bool:D :$normalize = True,
                   Bool:D :v(:$vector-result) = False,
                   Bool:D :$warn = True) {

        # Process $items
        $items = do given $items {
            when $_ ~~ Str:D { [$_, ].Mix}
            when $_ ~~ (Array:D | List:D | Seq:D) && $_.all ~~ Str:D {$_.Mix}
            when $_ ~~ Map:D {$_.Mix}
            when $_ ~~ Mix:D || $_ ~~ Math::SparseMatrix:D {$items}
            default {
                die 'Do not know how to process the first arugment.'
            }
        }

        # Make a vector of items
        my $histVec = $items ~~ Mix:D ?? self.to-history-vector($items) !! $items;

        die "If the first argument is a sparse matrix object then it is expected to be with dimensions (1, {self.take-M.rows-count})."
        unless $histVec.rows-count == 1 && $histVec.columns-count == self.take-M.rows-count;

        ## Compute the profile
        my $prof = $histVec.dot($!M);
        #my $prof = $histVec.to-adapted.dot($!M);
        #$prof.core-matrix = $prof.core-matrix.to-csr;

        ## Normalize
        if $normalize {
            $prof = self!max-normalize-sparse-matrix($prof, :abs-max);
        }

        if $vector-result {
            $!value = $prof;
        } else {
            ## Sort
            my @res = $prof.column-sums(:p).grep(*.value > 0).sort({  -$_.value }).map({ $_.key => $_.value });
            ## Result
            $!value = @res;
        }
        return self;
    }

    ##========================================================
    ## Recommend by history
    ##========================================================
    #| Recommend items for a consumption history (that is a list or a mix of items.)
    #| * C<@items> A list of items, a hashmap or mix of scored items, or 1-row Math::SparseMatrix object.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$remove-history> Should the history be removed from the result recommendations or not??
    #| * C<$warn> Should warnings be issued or not?
    method recommend($items is copy,
                     Numeric:D $nrecs is copy = 12,
                     Bool:D :$normalize = False,
                     Bool:D :$remove-history = True,
                     Bool:D :v(:$vector-result) = False,
                     Bool:D :$warn = True) {

        # Process $items
        $items = do given $items {
            when $_ ~~ Str:D { [$_, ].Mix}
            when $_ ~~ (Array:D | List:D | Seq:D) && $_.all ~~ Str:D {$_.Mix}
            when $_ ~~ Map:D {$_.Mix}
            when $_ ~~ Mix:D || $_ ~~ Math::SparseMatrix:D {$items}
            default {
                die 'Do not know how to process the first arugment.'
            }
        }

        # Make a vector of items
        my $vec = $items ~~ Mix:D ?? self.to-history-vector($items) !! $items;

        die "If the first argument is a sparse matrix object then it is expected to be with dimensions (1, {self.take-M.rows-count})."
        unless $vec.rows-count == 1 && $vec.columns-count == self.take-M.rows-count;

        # Compute recommendations
        my $rec = self.take-M.dot($vec.dot(self.take-M).transpose(:!clone));

        if $remove-history {
            my $hist0 = $vec.unitize(:clone).transpose.multiply(0);
            $hist0.implicit-value = 1;
            $rec = $rec.multiply($hist0)
        }

        $nrecs = round($nrecs);

        if $nrecs <= 0 {
            note 'The second argument is expected to be a positive integer or Inf.';
            self.set-value(%());
            return self;
        }

        ### Basically the same as the end of .recommend-by-profile()
        # Normalize
        if $normalize {
            $rec = self!max-normalize-sparse-matrix($rec, :abs-max);
        }

        # Vector result
        if $vector-result {

            if $nrecs < $rec.rows-count {
                my %recs2 = $rec.row-sums(:p);
                my @recs2 = %recs2.grep(*.value > 0).sort(-*.value)>>.key[^$nrecs];
                $rec = $rec[@recs2;*].impose-row-names($rec.row-names);
            }

        } else {
            ## Sort
            my @res = $rec.row-sums(:p).sort({ -$_.value }).map({ $_.key => $_.value });

            ## Result
            $rec = @res.head(min($nrecs, @res.elems)).Array;
        }

        # Assign obtained recommendations to the pipeline value
        $!value = $rec;

        return self;
    }

    ##========================================================
    ## Recommend by profile
    ##========================================================
    #| Recommend items for a consumption profile (that is a list or a mix of tags.)
    #| * C<$tags> A list of tags, a hashmap or a mix of scored tags, or 1-column sparse matrix.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    method recommend-by-profile($tags is copy,
                                Numeric:D $nrecs is copy = 12,
                                Bool:D :$normalize = True,
                                Bool:D :v(:$vector-result) = False,
                                Bool:D :$warn = True) {

        # Process $tags
        $tags = do given $tags {
            when $_ ~~ Str:D { [$_, ].Mix}
            when $_ ~~ (Array:D | List:D | Seq:D) && $_.all ~~ Str:D {$_.Mix}
            when $_ ~~ Map:D {$_.Mix}
            when $_ ~~ Mix:D || $_ ~~ Math::SparseMatrix:D {$tags}
            default {
                die 'Do not know how to process the first arugment.'
            }
        }

        # Make a vector of items
        my $vec = $tags ~~ Mix:D ?? self.to-profile-vector($tags) !! $tags;

        die "If the first argument is a sparse matrix object then it is expected to be with dimensions (1, {self.take-M.columns-count})."
        unless $vec.columns-count == 1 && $vec.rows-count == self.take-M.columns-count;

        # Process number of recommendations
        $nrecs = round($nrecs);

        if $nrecs <= 0 {
            note 'The second argument is expected to be a positive integer or Inf.';
            self.set-value(%());
            return self;
        }

        ## Compute recommendations
        my $rec = $!M.dot($vec);
        #my $rec = $!M.to-adapted.dot($svec.to-adapted);
        #$rec.core-matrix = $rec.core-matrix.to-csr;

        ## Normalize
        if $normalize {
            $rec = self!max-normalize-sparse-matrix($rec, :abs-max);
        }

        # Vector result
        if $vector-result {

            if $nrecs < $rec.rows-count {
                my %recs2 = $rec.row-sums(:p);
                my @recs2 = %recs2.grep(*.value > 0).sort(-*.value)>>.key[^$nrecs];
                $rec = $rec[@recs2;*].impose-row-names($rec.row-names);
            }

        } else {
            ## Sort
            my @res = $rec.row-sums(:p).sort({ -$_.value }).map({ $_.key => $_.value });

            ## Result
            $rec = @res.head(min($nrecs, @res.elems)).Array;
        }

        # Assign obtained recommendations to the pipeline value
        $!value = $rec;

        return self;
    }

    ##========================================================
    ## Filter by profile
    ##========================================================
    #| Filter items by profile.
    #| * C<$prof> A profile specification used to filter with.
    #| * C<$type> The type of filtering one of "union" or "intersection".
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method filter-by-profile(Mix:D $prof,
                                   Str :$type = 'intersection',
                                   Bool :$object = True,
                                   Bool :$warn = True) {
        return self.filter-by-profile($prof.keys, :$type, :$object, :$warn);
    }

    multi method filter-by-profile(@prof,
                                   Str :$type = 'intersection',
                                   Bool :$object = True,
                                   Bool :$warn = True) {
        my %profMix;
        if $type.lc eq 'intersection' {
            my $profileVec = self.to-profile-vector(@prof.Mix);
            my %sVec = self.take-M.unitize(:clone).dot($profileVec).row-sums(:pairs);
            my $n = $profileVec.column-sums.head;
            %profMix = %sVec.grep({ $_.value >= $n });

        } elsif $type.lc eq 'union' {

            %profMix = self.recommend-by-profile(@prof).take-value

        } else {
            note 'The value of the type argument is expected to be one of \'intersection\' or \'union\'.' if $warn;
            self.set-value(%());
            return self;
        }

        ## Result
        self.set-value(%profMix.keys.List);

        return self;
    }

    ##========================================================
    ## Retrieve by query elements
    ##========================================================
    # TBD...

    ##========================================================
    ## Classify
    ##========================================================
    #| Classify by profile vector.
    #| C<$tagType> -- Tag type to classify to.
    #| C<$profile> -- A tag, a list of tags, a dictionary of scored tags.
    #| C<:$n-top-nearest-neighbors> -- Number of top nearest neighbors to use.
    #| C<:$voting> -- Should simple voting be used or a weighted sum?
    #| C<:$max-number-of-labels> -- The maximum number of labels to be returned; if None all found labels are returned.
    #| C<:$drop-zero-scored-labels> -- Should the labels with zero scores be dropped or not?
    #| C<:$normalize> -- Should the scores be normalized?
    #| C<:$ignore-unknown> -- Should the unknown tags be ignored or not?
    #| C<$object> -- Should the result be an object or not?
    multi method classify-by-profile(Str $tagType, @profile, *%args) {
        return self.classify-by-profile($tagType, %(@profile X=> 1.0).Mix, |%args);
    }

    multi method classify-by-profile(Str:D $tag-type,
                                     Mix:D $profile,
                                     UInt:D :$n-top-nearest-neighbors = 100,
                                     Bool:D :$voting = False,
                                     Bool:D :$drop-zero-scored-labels = True,
                                     :$max-number-of-labels = Whatever,
                                     Bool:D :$normalize = True,
                                     Bool:D :$warn = False) {

        # Verify tag type
        unless $tag-type ∈ self.take-matrices.keys {
            die "The value of the first argument is not a known tag type.";
        }

        # Compute the recommendations
        my $recs = self.recommend-by-profile(
                $profile,
                $n-top-nearest-neighbors,
                :vector-result,
                :$warn
                ).take-value;

        # "Nothing" result
        if $recs.column-sums.head== 0 {
            self.set-value(%());
            return self;
        }

        # Get the tag type matrix
        my $mat-tag-type = self.take-matrices{$tag-type}.clone;

        # Transpose in place
        $recs = $recs.transpose;

        # Respect voting
        if $voting {
            $recs.unitize(:!clone);
        }

        # Get scores
        my $cl-res = $recs.dot($mat-tag-type);

        # Convert to dictionary
        $cl-res = $cl-res.column-sums(:pairs);

        # Drop zero scored labels
        if $drop-zero-scored-labels {
            $cl-res = $cl-res.grep({ .value > 0 }).Hash;
        }

        # Normalize
        if $normalize {
            my $cl-max = $cl-res.values.max;
            if $cl-max > 0 {
                $cl-res = $cl-res.map({ .key => .value / $cl-max }).Hash;
            }
        }

        # Reverse sort
        $cl-res = $cl-res.sort({ -$_.value }).Hash;

        # Pick max-top labels
        if $max-number-of-labels && $max-number-of-labels < $cl-res.elems {
            $cl-res = $cl-res.List[^$max-number-of-labels].Hash;
        }

        # Result
        self.set-value($cl-res);

        return self;
    }

    ##========================================================
    ## Join across
    ##========================================================
    multi method join-across($data, $on) {
        return self.join-across($data, :$on);
    }

    multi method join-across($dsData is copy = Whatever, :$on is copy = Whatever) {

        # Check pipeline's value
        unless $!value ~~ Map:D || $!value ~~ (Array:D | List:D | Seq:D) && $!value.all ~~ Pair:D {
            note 'The pipeline value is not a hashmap or list of scored items.';
            return self;
        }

        # Process data
        die 'The first argument is expected to be a list of hashmaps or Whatever.'
        unless $dsData.isa(Whatever) || $dsData ~~ (Array:D | List:D | Seq:D) && $dsData.all ~~ Map:D;

        if $dsData.isa(Whatever) {
            die 'The data attribute is not a list of hashmaps.'
            unless $!data ~~ (Array:D | List:D | Seq:D) && $!data.all ~~ Map:D;
            $dsData = $!data
        }

        # Check data for being homogeneous
        # TBD

        # Process binding field
        die 'The argument $on is expected to be a strinng or Whatever.'
        unless $on.isa(Whatever) || $on ~~ Str:D;

        if $on.isa(Whatever) {
            $on = do given $dsData.head {
                when $_.keys.grep(* ∈ <id Id ID>).elems > 0 {
                    $_.keys.first(* ∈ <id Id ID>)
                }
                when $_.keys.grep( *.lc eq item ).elems > 0 {
                    $_.keys.first(*.lc eq item )
                }
                when $_.keys.grep(* ~~ /:i ['_' | '-' | '.'] 'id' /).elems > 0 {
                    $_.keys.first(* ~~ /:i  ['_' | '-' | '.']  'id' /)
                }
                default {
                    die 'Cannot guess item column name to join across on.'
                }
            }
        }

        my %recordPos = $dsData.kv.map( -> $k, %v { %v{$on} => $k });

        my @res;
        for |$!value -> $p {
            if %recordPos{$p.key}:exists {
                my %record = $dsData[%recordPos{$p.key}];
                my %h = %(score => $p.value) , %record;
                @res.push(%h)
            }
        }

        self.set-value(@res);
        return self
    }

    ##========================================================
    ## Prove by metadata
    ##========================================================
    multi method prove-by-metadata(@profile, @items) {
        return self.prove-by-metadata(%( @profile X=> 1.0), @items);
    }

    multi method prove-by-metadata(%profile, @items) {
        note "Proving by metadata is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Prove by history
    ##========================================================
    multi method prove-by-history(@history, @items) {
        return self.prove-by-history(%( @history X=> 1.0), @items);
    }

    multi method prove-by-history(%history, @items) {
        note "Proving by history is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Filter matrix
    ##========================================================
    multi method filter-matrix(%profile) {
        return self.filter-matrix(%profile.values);
    }

    multi method filter-matrix(@profile) {
        note "Filter matrix is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Remove tag type(s)
    ##========================================================
    #| Remove tag types.
    #| * C<@tagTypes> A tag type of a list of tag types to be removed
    method remove-tag-types($tag-types is copy, Bool :$warn = True) {
        my @remove-tag-types = $tag-types ~~ Str:D ?? [$tag-types,] !! $tag-types;

        die "The first argument  is expected to be a string or a list of strings."
        unless @remove-tag-types.all ~~ Str:D;

        my @known-tag-types = self.take-matrices.keys;
        my @tag-types-known = (@known-tag-types (&) @remove-tag-types).keys;

        die "None of the specified tag types is a known tag type in the recommender object."
        unless @tag-types-known.elems > 0;

        if @tag-types-known.elems < @remove-tag-types.elems && $warn {
            note "Some tags are not known in the recommender.";
        }

        my @tag-types-remaining = (@known-tag-types (-) @remove-tag-types).keys;

        my %matrices = self.take-matrices;
        my %filtered = %matrices.grep({ $_.key ∈ @tag-types-remaining });

        return ML::SparseMatrixRecommender.new(%filtered);
    }

    ##========================================================
    ## Recommenders algebra -- Join
    ##========================================================
    method join(ML::SparseMatrixRecommender:D $other, Str $join-type = 'left', *@args) {
        my @all-row-names = self.take-m().row-names;
        if $join-type ne 'same' {
            if $join-type eq 'outer' || $join-type eq 'union' {
                @all-row-names = (self.take-m().row-names + $other.take-m().row-names).unique;
            }
            elsif $join-type eq 'inner' {
                my %names1 = self.take-m().row-names».self;
                my %names2 = $other.take-m().row-names».self;
                @all-row-names = [ %names1.keys & %names2.keys ].list;
            }
            elsif $join-type eq 'left' {
                @all-row-names = self.take-m().row-names;
            }
            else {
                die 'The second argument is expected to be one of "same", "outer", "inner", "left".';
            }
        }

        my %SMats1 = self.take-matrices;
        my %SMats2 = $other.take-matrices;

        my @common-tags = (%SMats1.keys (&) %SMats2.keys).keys;
        if @common-tags.elems > 0 {
            warn "The tag types { @common-tags.sort.join(', ') } are also in the SMR argument, hence will be dropped.";
        }

        if $join-type ne 'same' {
            %SMats1 = %SMats1.kv.map: { $_ => %SMats1{$_}.impose-row-names(@all-row-names) };
            %SMats2 = %SMats2.kv.map: { $_ => %SMats2{$_}.impose-row-names(@all-row-names) };
        }

        my %matrices = %SMats1 , %SMats2;

        return ML::SparseMatrixRecommender.new(%matrices);
    }

    ##========================================================
    ## Recommenders algebra -- Annex matrix
    ##========================================================
    method annex-sub-matrix($matrices) {
        die 'The first argument, mats, is expected to be a hashmap of Math::SparseMatrix objects.'
        unless $matrices ~ Map:D && $matrices.values ~~ Math::SparseMatrix:D;

        return self.join(ML::SparseMatrixRecommender.new($matrices));
    }

    ##========================================================
    ## Recommenders algebra -- To tag type recommender
    ##========================================================
    method make-tag-type-recommender(Str $tagTypeTo, @tagTypes) {
        note "Tag type recommender making is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Representation
    ##========================================================
    #| To Hash
    multi method Hash(::?CLASS:D:-->Hash) {
        return
                {
                    matrices => self.take-matrices,
                    tag-type-weights => self.take-tag-type-weights,
                    data => self.take-data,
                    value => self.take-value,
                };
    }

    #| To string
    multi method Str(::?CLASS:D:-->Str) {
        return self.gist;
    }

    #| To gist
    multi method gist(::?CLASS:D:-->Str) {
        return 'ML::SparseMatrixRecommender' ~ (matrix-dimensions => (self.take-M.rows-count, self.take-M.columns-count),
                                                density => self.take-M.density,
                                                tag-types => self.take-matrices.elems ≤ 12 ?? self.take-matrices.keys.List !! self.take-matrices.elems).List.raku;
    }
}
