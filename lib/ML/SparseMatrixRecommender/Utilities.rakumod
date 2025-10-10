use v6.d;

unit module ML::SparseMatrixRecommender::Utilities;

#| Get the Titanic dataset. Returns an array of hashmaps.
our sub get-titanic-dataset() {
    my $fileResource = %?RESOURCES<dfTitanic.csv>;

    my @lines = slurp($fileResource).subst('"', :g).lines;
    my @keys = @lines.head.split(',', :skip-empty).Array;
    my @tbl = do for @lines.tail(*-1).grep(*) -> $line {
        (@keys Z=> $line.split(',', :skip-empty).Array).Hash
    }
    return @tbl;
}
#= Ingests the resource file "dfTitanic.csv" of ML::SparseMatrixRecommender.
