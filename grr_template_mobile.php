<?php
/*
Template Name: Mobile
*/
?>

<?php
define('GRR_SHOW_EVENTS', 			1);
define('GRR_SHOW_RESULTS',			2);
define('GRR_GET_COLUMNS', 			3);
define('GRR_GET_SUBRACES', 			4);
define('GRR_GET_DIVISIONS',			5);
define('GRR_GET_1_MONTH_EVENTS',	6);
define('GRR_GET_RACES_IN_1_EVENT',	7);
define('GRR_SHOW_1_RESULT',			8);
define('GRR_GET_BOOKMARK_INFO',		9);
define('GRR_SHOW_COLUMNS_IN_1_TABLE', 10);

global $wpdb, $wp_query;
$action	= $_REQUEST['action'];

switch ($action)
{
	case GRR_GET_1_MONTH_EVENTS:

		$year = $_GET['year'];
		$month = $_GET['month'];
		
		$endYear 	= $year;
		$endMonth 	= $month + 1;
		
		if ($endMonth == 13)
		{
			$endMonth = 1;
			$endYear++;
		}
		
		$resultArray 	= array();
			
		$sql = "SELECT `ID`, `post_title`, `post_date` FROM `wp_posts` WHERE `post_status` = 'publish' AND `post_type` = 'post' AND `post_date` >= '" . $year . "-" . str_pad($month, 2, "0", STR_PAD_LEFT) . "-01 00:00:00' AND `post_date` < '" . $endYear . "-" . str_pad($endMonth, 2, "0", STR_PAD_LEFT) . "-01 00:00:00' ORDER BY `post_date`";
			
		$events = $wpdb->get_results($sql, ARRAY_N); 

		foreach ($events as $row)  
		{				
			$post_id = $row[0];
			
			$array2	= array("ID" => $post_id,
							"post_title" =>  $row[1],
							"post_date" =>  $row[2],
							"_grr_race_location_city" => get_post_meta($post_id, "_grr_race_location_city", true), 
							"_grr_race_location_state" => get_post_meta($post_id, "_grr_race_location_state", true));

	  		array_push($resultArray, $array2);
		}

	    // Finally, encode the array to JSON and output the results
		header("Content-Type: application/json");
		echo json_encode($resultArray);
		break;

	case GRR_SHOW_1_RESULT:
		$resultArray 	= array();

		// Get the table name
		$table_name = $_GET['table'];

		// This is used to construct a url in the page combo.	
		$query = "";
		
		$bib_number = $_GET['bib_number'];
		$first_name = $_GET['first_name'];
		$last_name 	= $_GET['last_name'];
				
		// When a key word includes a single quote, it becomes \'.  Second time (one photo page), \' becomes \\\'. 
		$key_word = str_replace("\\\'", "'", $key_word);
		
		// Check if which column is used as finish time.  It must be either Chip or Total Time. 
		$query 			= "SELECT `COLUMN_NAME` FROM `INFORMATION_SCHEMA`.`COLUMNS` WHERE `TABLE_SCHEMA`='" . $wpdb->dbname . "' AND `TABLE_NAME`= '$table_name'";
		
		$column_array	= array();
		$tempo_array 	= $wpdb->get_results($query, ARRAY_N); 
		
		// The query avove returns arrays of one-item arrays.
		// Array data1
		// Array data2
		// etc.
		for ($i = 0; $i < count($tempo_array); $i++)
			array_push($column_array, $tempo_array[$i][0]);
		
		$query 			= "SELECT * FROM `" . $table_name . "` WHERE `Bib` = '" . $bib_number . "' AND `First Name` = '" . $first_name . "' AND `Last Name` = '" . $last_name . "' LIMIT 1;";
			
		$data_array 	= $wpdb->get_results($query, ARRAY_N); 
		// The query avove returns one array of one array, which has data.
		// Array
		//		Array
		//			data 1
		// 			data 2
		//			etc.
	 	
		array_push($resultArray, $column_array);
		array_push($resultArray, $data_array[0]);

	    // Finally, encode the array to JSON and output the results
	    header("Content-Type: application/json");
	    echo json_encode($resultArray);

		break;	
}
?>