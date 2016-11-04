<?php

error_reporting(E_ALL);

$file = 'output.csv';

// Function idea: https://gist.github.com/jaywilliams/385876
// Function to read CSV into array of arrays.
function csv_to_array($filename='', $delimiter=',')
{
	if(!file_exists($filename) || !is_readable($filename))
		return FALSE;
	
	$header = NULL;
	$data = array();
	if (($handle = fopen($filename, 'r')) !== FALSE)
	{
		while (($row = fgetcsv($handle, 1000, $delimiter)) !== FALSE)
		{
			if(!$header)
				$header = $row;
			else
				$data[] = array_combine($header, $row);
		}
		fclose($handle);
	}
	return $data;
}

$csvarr = csv_to_array($file,';');

/*
EXAMPLE for JSON output format, supported by HighMaps;
?([
	{
		"code": "AF",
		"value": 53,
		"name": "Afghanistan"
	},
	{
      ...
    }
    ]);
*/

$newarr = Array();

// Foreach line in the input dataset produce a JSON array. Dit example only produces only a JSON file with the population in 1990
// Code can be further adapted to include other years and other data from input dataset
foreach ($csvarr as $line)
{
	if(sizeof($line['Countrycode']) > 0)
	{
		$tmparr = Array('code' => $line['Countrycode'], 'value' => $line['1990'], 'name' => $line['Countrycode'].' population in 1990');
		array_push($newarr, $tmparr);
	}
}

header('Content-Type: application/json');
echo "?(";
echo json_encode($newarr, JSON_PRETTY_PRINT);
echo ");\n";

?>
