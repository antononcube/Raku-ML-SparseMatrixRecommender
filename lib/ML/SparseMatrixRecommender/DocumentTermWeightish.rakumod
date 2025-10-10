use v6.d;

use Math::SparseMatrix;

role ML::SparseMatrixRecommender::DocumentTermWeightish {

    method !max-normalize-sparse-matrix(Math::SparseMatrix:D $mat, Bool:D :$clone = False, Bool:D :$abs-max = False) {
        my $max = $abs-max ?? $mat.Array.flat(:hammer)>>.abs.max !! $mat.Array.flat(:hammer).max;
        $max = $max.abs > 0 ?? (1.0 / $max).Num !! 1.0;
        return $mat.multiply($max, $clone);
    }

    method global-term-function-weights($doc-term-matrix, $func is copy = Whatever) {
        die 'The argument $doc-term-matrix is expected to be a Math:SparseMatrix object.'
        unless $doc-term-matrix ~~ Math::SparseMatrix:D;

        if $func.isa(Whatever) { $func = 'Binary' }
        die "The argument func is expected to be a string or Whatever."
        unless $func ~~ Str:D;

        my $mat = $doc-term-matrix.clone;

        given $func.lc {
            when $_ eq 'idf' {
                $mat.unitize(:!clone);
                my @global-weights = $mat.column-sums;
                return @global-weights.map({ $_ > 0 ?? log($mat.rows-count / $_, 2) !! 1 });
            }
            when $_ ∈ <idf-smooth idf_smooth idfsmooth> {
                $mat.unitize(:!clone);
                my @global-weights = $mat.column-sums;
                return @global-weights.map({ log($mat.rows-count / (1 + $_), 2) + 1 });
            }
            when $_ eq 'gfidf' {
                my @freq-sums = $mat.column-sums;
                $mat.unitize(:!clone);
                my @global-weights = $mat.column-sums;
                @global-weights = @global-weights.map({ $_ == 0 ?? 1 !! $_ });
                return @freq-sums Z/ @global-weights;
            }
            when $_ eq 'normal' {
                my @global-weights = $mat.multiply($mat).column-sums.map({ sqrt($_) });
                @global-weights = @global-weights.map({ $_ == 0 ?? 1 !! $_ });
                return @global-weights.map({ 1 / $_ });
            }
            when $_ ∈ <binary none> {
                return (1 xx $mat.columns-count);
            }
            when $_ ∈ <columnstochastic column-stochastic sum> {
                $mat.unitize(:!clone);
                my @global-weights = $mat.column-sums;
                @global-weights = @global-weights.map({ $_ == 0 ?? 1 !! $_ });
                return @global-weights.map({ 1 / $_ });
            }
            when $_ eq 'entropy' {
                die "Global weight function Entropy is not implemented.";
            }
            default {
                die "Unknown global weight function specification for the argument func.";
            }
        }
    }
    
    method apply-lsi-weight-functions($doc-term-matrix,
                                      $global-weight-func is copy = Whatever,
                                      $local-weight-func is copy = Whatever,
                                      $normalizer-func is copy = Whatever) {
        die 'The argument $doc-term-matrix is expected to be a Math::SparseMatrix object.'
        unless $doc-term-matrix ~~ Math::SparseMatrix:D;

        if $local-weight-func.isa(Whatever) { $local-weight-func = 'None' }
        die "The argument local-weight-func is expected to be a string or Whatever."
        unless $local-weight-func ~~ Str:D;

        if $normalizer-func.isa(Whatever) { $normalizer-func = 'None' }
        die "The argument normalizer-func is expected to be a string."
        unless $normalizer-func ~~ Str:D;

        my @global-weights;
        if $global-weight-func.isa(Whatever) { $global-weight-func = 'None' }
        if $global-weight-func ~~ Str:D {
            @global-weights = self.global-term-function-weights($doc-term-matrix, $global-weight-func);
        } elsif $global-weight-func ~~ (Array:D | List:D | Seq:D) && $global-weight-func.elems == $doc-term-matrix.columns-count {
            @global-weights = $global-weight-func;
        } else {
            die 'The argument global-weight-func is expected to be Whatever, a string, or a numeric vector with length that equals $doc-term-matrix.columns_count'
        }

        my $mat = $doc-term-matrix.clone;

        given $local-weight-func.lc {
            when "log" | "logarithmic" {
                $mat.core-matrix.apply-elementwise({log($_ + 1)} , :skip-implicit-value, :!clone);
            }
            when "termfrequency" | "none" {
                # No operation needed
            }
            default {
                die "Unknown local weight function specification for the argument local-weight-func.";
            }
        }

        my @diagonal-rules = (^@global-weights.elems).kv.map( -> $i, $v { ($i, $i) => $v });
        my $diag-mat = Math::SparseMatrix.new(rules => @diagonal-rules, row-names => $mat.column-names, column-names => $mat.column-names);
        $mat = $mat.dot($diag-mat);
        $mat.set-column-names($doc-term-matrix.column-names);

        given $normalizer-func.lc {
            when $_ eq "cosine" {
                my @svec = $mat.multiply($mat, :clone).row-sums.map({ sqrt($_) });
                @svec = @svec.map({ $_ == 0 ?? 1.0 !! (1.0 / $_) });
                my @rules = @svec.kv.map( -> $i, $v { ($i, $i) => $v });
                my $diag-mat = Math::SparseMatrix.new(:@rules, row-names => $mat.row-names, column-names => $mat.row-names);
                $mat = $diag-mat.dot($mat);
            }
            when $_ ∈ <sum rowstochastic> {
                my @svec = $mat.row-sums;
                @svec = @svec.map({ $_ == 0 ?? 1.0 !! (1.0 / $_) });
                my @rules = @svec.kv.map( -> $i, $v { ($i, $i) => $v });
                my $diag-mat = Math::SparseMatrix.new(:@rules, row-names => $mat.row-names, column-names => $mat.row-names);
                $mat = $diag-mat.dot($mat);
            }
            when $_ ∈ <max maximum> {
                my $smat = self.max-normalize-sparse-matrix($mat, False);
                #$mat.set-sparse-matrix($smat);
            }
            when $_ ∈ <absmax absmaximum> {
                my $smat = self.max-normalize-sparse-matrix($mat.core-matrix, True);
                $mat.set-sparse-matrix($smat);
            }
            when $_ eq 'none' {
                # No operation needed
            }
            default {
                die "Unknown local weight function specification for the argument normalizer-func.";
            }
        }

        return $mat;
    }
}
