#!\sbin\perl

use strict;
use warnings;

my @country_name_to_code_head = ();
my %country_name_to_code;
my %eu_emission_total;
my @eu_emission_total_head = ();
my %world_emission_total;
my @world_emission_total_head = ();
my %country_population_total;
my @country_population_head = ();
my %eu_emission_per_capita;

# FILE GHG world: http://www.wri.org/resources/data-sets/cait-historical-emissions-data-countries-us-states-unfccc
# FILE GHG transport EU: https://data.europa.eu/euodp/en/data/dataset/BgKwU3HTkDyftNQpDM4g
# FILE country codes: https://datahub.io/dataset/iso-3166-1-alpha-2-country-codes/resource/9c3b30dd-f5f3-4bbe-a3cb-d7b2c21d66ce
# FILE population: http://data.worldbank.org/indicator/SP.POP.TOTL

# Load the ISO country codes and country names couples into a hash
open(FH, "<iso_3166_2_countries.csv");
while (my $line = <FH>)
{
	$line =~ s/\n|\r//gi;

	if($#country_name_to_code_head <= 0)
	{
		@country_name_to_code_head = split(/\,/, $line);
	}
	else
	{
        my @arr = split(/\,/, $line);
		$country_name_to_code{$arr[1]} = $arr[10]; # A hash with keys = country names and values = 2 letter country codes
	}
}
close(FH);

# Open and load EU Transport GHG data into a hash, with country code as refrence
open(FH, "<EU Transport GHG emissions - tsdtr410.tsv");
while (my $line = <FH>)
{
	$line =~ s/\n|\r//gi;
	$line =~ s/\t/,/gi;
	$line =~ s/\s*//gi;

	if($#eu_emission_total_head <= 0)
	{
		@eu_emission_total_head = split(/\,/, $line);
	}
	else
	{
        my @arr = split(/\,/, $line);
        shift(@arr);
        shift(@arr);
        shift(@arr);
        my $countrycode = $arr[0];
        shift(@arr);
		$eu_emission_total{$countrycode} = [@arr]; # A hash of arrays
	}
}
close(FH);

# Open and load World total GHG emissions per country into a hash, with country code as refrence
open(FH, "<World total GHG emissions - CAIT_Country_GHG_Emissions_-_csv_1216 - CAIT Country GHG Emissions.csv");
while (my $line = <FH>)
{
    next if ($. == 1 || $. == 2); # Skip first two lines of csv
	$line =~ s/\n|\r//gi;

	if($#world_emission_total_head <= 0)
	{
		@world_emission_total_head = split(/\,/, $line);
	}
	else
	{
        my @arr = split(/\,/, $line);
        my $countryname = $arr[0];
        my $year = $arr[1];
        my $total_ghg = $arr[3];
        if ($year =~ /^\d+?$/)
        {
            my $countrycode = &getCountryCode($countryname);
    		$world_emission_total{$countrycode}[($year-1990)] = $total_ghg; # A hash of arrays; hash of country codes with array val = year and array elements are years where 0 = 1990
        }
	}
}
close(FH);

# Open and load population per country in a hash, with country code as refrence
open(FH, "<World population per country per year - API_SP.POP.TOTL_DS2_en_csv_v2 API_SP.POP.TOTL_DS2_en_csv_v2.csv");
while (my $line = <FH>)
{
    next if ($. == 1 || $. == 2 || $. == 3 || $. == 4); # Skip first two lines of csv
	$line =~ s/\n|\r//gi;
	$line =~ s/"//gi;

	if($#country_population_head <= 0)
	{
		@country_population_head = split(/\,/, $line);
	}
	else
	{
        my @arr = split(/\,/, $line);
        my $countryname = $arr[0];
        my $countrycode = &getCountryCode($countryname);
		shift @arr for 1..4; # remove first four elements of row that contains country ids
		shift @arr for 1..30; # remove first 30 years of data because our dataset starts at 1990
		$country_population_total{$countrycode} = [@arr]; # A hash of arrays
	}
}
close(FH);

#Create hash with transport GHG output per capita, using earlier loaded hashes
foreach my $key (sort keys %eu_emission_total) # $key = country code
{
    if($eu_emission_total{$key} && $country_population_total{$key})
    {
        my @eu_transport = @{ $eu_emission_total{$key} };
        my @population = @{ $country_population_total{$key} };
      my @newarr = ();
      for (my $i=0; $i<=$#eu_transport; $i++ )
      {
        if($eu_transport[$i] > 0)
        {
            push(@newarr, sprintf("%.8f", ($eu_transport[$i]/$population[$i]*1000000)) );
        }
      }
      $eu_emission_per_capita{$key} = [@newarr];
    }
}

# BEGIN: CREATE MERGED FILE, using earlier loaded hashes
open(FH, ">output.csv");
print FH "Countrycode;Type;Unit;".join(';',(1990..2016))."\n";
foreach my $key (sort keys %eu_emission_total) # $key = country code
{
    my @val = @{ $eu_emission_total{$key} };
    if($world_emission_total{$key})
    {
        my $join_years = join(';', @{ $world_emission_total{$key} } );
        print FH $key.";TotalGHG;MillionMerticTonnes;".$join_years."\n";

        $join_years = join(';', @{ $eu_emission_total{$key} } );
        print FH $key.";TransportGHG;MillionMerticTonnes;".$join_years."\n";

        $join_years = join(';', @{ $country_population_total{$key} } );
        print FH $key.";PopulationCount;Individuals;".$join_years."\n";

        $join_years = join(';', @{ $eu_emission_per_capita{$key} } );
        print FH $key.";TransportGHGPerCapita;MetricTonnesPerIndividual;".$join_years."\n";
    }
}
close(FH);
# END: CREATE MERGED FILE, using earlier loaded hashes

sub getCountryCode(){ # Convert a country name to a 2 letter country code
    my $countryname = $_[0];
    foreach my $key (keys %country_name_to_code){
        my $countrycode = $country_name_to_code{$key};
        if(lc($countryname) eq lc($key))
        {
            return $countrycode;
        }
    }
}
