We can use some basic Shell and SQL tools to build and query a database.

# Datasets

I started a dataset for the Fungi5k exploration project. Here I put files in the [data](data) folder. These are CSV files.
* [samples.csv.gz](data/samples.csv.gz) - this is the metadata about each genome in the project. The columns are relatively explanatory and first line of file is a header.
* [asm_stats.csv.gz](data/asm_stats.csv.gz) - Genome assembly stats
* [aa_freq.csv.gz](data/aa_freq.csv.gz) - this is computed amino acid usage frequency for each organism, the `species_prefix` is the code that can be linked to samples.csv `LOCUSTAG` column
* [species_funguild.csv.gz](data/species_funguild.csv.gz) - this is the funguild imputed ecology or guild for the organisms which could be assigned (or sometimes it is transferred from the genus assignment)


# Loading a DuckDB SQL db

See [DuckDB Guide](https://duckdb.org/docs/guides/overview) for starters.

On the command line or in a script you can do the following to load a db and create static file for future queries. DuckDB can also be run on the fly (eg no static DB made or loaded)
```bash
module load duckdb
# build species table
duckdb -c "CREATE TABLE IF NOT EXISTS species AS SELECT * FROM read_csv_auto('data/samples.csv.gz')" fungigenomeDB.duckdb
duckdb -c "CREATE INDEX IF NOT EXISTS idx_species_locustag ON species(LOCUSTAG)" fungigenomeDB.duckdb
```
That will create a file called `fungigenomeDB.duckdb` that will be queriable.

We can now run a simple set of queries on it

```bash
module load duckdb
# count the number of organisms in the database
duckdb -c "SELECT COUNT(*) from species" fungigenomeDB.duckdb
# count how many are Ascomycota
duckdb -c "SELECT COUNT(*) from species where PHYLUM='Ascomycota'" fungigenomeDB.duckdb
# do a query and print the results
duckdb -c "SELECT * from species WHERE PHYLUM='Zoopagomycota' OR PHYLUM='Mucoromycota'" fungigenomeDB.duckdb
```

Now let's do a more complex query, let's add in the funguild and amino acid frequency data.

```bash
# Add AA freq
duckdb -c "CREATE TABLE IF NOT EXISTS aa_frequency AS SELECT * FROM read_csv_auto('data/aa_freq.csv.gz')" fungigenomeDB.duckdb
duckdb -c "CREATE INDEX IF NOT EXISTS idx_aa_locustag ON aa_frequency(species_prefix)" fungigenomeDB.duckdb

# add funguild
duckdb -c "CREATE TABLE IF NOT EXISTS funguild AS SELECT * FROM read_csv_auto('data/species_funguild.csv.gz')" fungigenomeDB.duckdb
duckdb -c "CREATE INDEX IF NOT EXISTS idx_funguild_locustag ON funguild(species_prefix)" fungigenomeDB.duckdb

# build asm stats table
duckdb -c "CREATE TABLE IF NOT EXISTS asm_stats AS SELECT * FROM read_csv_auto('data/asm_stats.csv.gz')" fungigenomeDB.duckdb
duckdb -c "CREATE INDEX IF NOT EXISTS idx_asmstats_locustag ON asm_stats(LOCUSTAG)" fungigenomeDB.duckdb
```

Now let's query funguild first by doing a JOIN using the WHERE clause.

```bash
duckdb -c "SELECT sp.PHYLUM, sp.GENUS, sp.SPECIES, sp.STRAIN, funguild.* FROM species as sp, funguild WHERE sp.LOCUSTAG = funguild.species_prefix" fungigenomeDB.duckdb
```

This will give back the composite of the columns we requested across the two tables. This is just a helpful way to see the datasets joined together.

Now let's compute something a little more complicated, how many Fungi in the Phylum Ascomycota are classified as Saprotrophs?

```bash
duckdb -c "SELECT sp.PHYLUM, sp.GENUS, sp.SPECIES, sp.STRAIN, funguild.* FROM species as sp, funguild WHERE sp.LOCUSTAG = funguild.species_prefix AND sp.PHYLUM='Ascomycota' AND trophicMode='Saprotroph'" fungigenomeDB.duckdb
```

But this misses some with two classifications "Saprotrophic-Symbiotroph" so let's relax this using the LIKE operator which will allow us to use regular expressions, in this case the `%` is a wildcard that matches anything
```bash
duckdb -c "SELECT sp.PHYLUM, sp.GENUS, sp.SPECIES, sp.STRAIN, funguild.* FROM species as sp, funguild WHERE sp.LOCUSTAG = funguild.species_prefix AND sp.PHYLUM='Ascomycota' AND trophicMode LIKE '%Saprotroph%'" fungigenomeDB.duckdb
```

But what if we want Symbiotroph AND Saprotroph but NOT Pathotroph (eg pathogen)
```bash
duckdb -c "SELECT sp.PHYLUM, sp.GENUS, sp.SPECIES, sp.STRAIN, funguild.* FROM species as sp, funguild WHERE sp.LOCUSTAG = funguild.species_prefix AND sp.PHYLUM='Ascomycota' AND trophicMode LIKE '%Saprotroph%' AND trophicMode NOT LIKE '%Pathotroph%'" fungigenomeDB.duckdb
```

We can also collapse data and get counts by categories using GROUP BY. We can also sort data using the ORDER BY operator 

```bash
# count number of organisms grouped by PHYLUM 
duckdb -c "SELECT sp.PHYLUM, COUNT(*) as taxon_count FROM species as sp GROUP BY sp.PHYLUM ORDER BY taxon_count" ./fungigenomeDB.duckdb
# reverse the order
duckdb -c "SELECT sp.PHYLUM, COUNT(*) as taxon_count FROM species as sp GROUP BY sp.PHYLUM ORDER BY taxon_count DESC" ./fungigenomeDB.duckdb
# a more complicated grouping to group by two categories
duckdb -c "SELECT sp.PHYLUM, funguild.growthForm, COUNT(*) FROM species as sp, funguild WHERE sp.LOCUSTAG = funguild.species_prefix GROUP BY sp.PHYLUM, funguild.growthForm ORDER BY growthForm" ./fungigenomeDB.duckdb
duckdb -c "SELECT sp.PHYLUM, funguild.trophicMode, COUNT(*) FROM species as sp, funguild WHERE sp.LOCUSTAG = funguild.species_prefix GROUP BY sp.PHYLUM, funguild.trophicMode ORDER BY PHYLUM" ./fungigenomeDB.duckdb
```
