<script>
	function loopForm() 
	{
		var cbResults = '';
	
		for (i = 0; i < document.OrderPage.elements.length; i++ ) 
		{
			if (document.OrderPage.elements[i].type == 'checkbox') 
			{
				if (document.OrderPage.elements[i].checked == true)
				{
					if (cbResults != '')
						cbResults +=  ', ';
	
					// Remove the very last ',' in the search function.
					cbResults += document.OrderPage.elements[i].value;
				}
			}
		}
	
		if (cbResults == '')
		{
			alert('Please choose at least one image.');
			return false;
		}
		else
		{
			document.getElementById('selected_orders').value = cbResults;
		}
	
		return true; 					
	}
	
	function checkData(button_id) 
	{
		switch(button_id) 
		{
			case 'Received_To_Lab':								
				document.getElementById('old_status').value = 'Received';
				document.getElementById('new_status').value = 'In the Print Lab';
				break;
	
			case 'Received_To_Shipped':
				document.getElementById('old_status').value = 'Received';
				document.getElementById('new_status').value = 'Shipped';
				break;
				
			case 'Lab_To_Shipped':
				document.getElementById('old_status').value = 'In the Print Lab';
				document.getElementById('new_status').value = 'Shipped';
			break;
		}
	
		return loopForm();
	}
</script>
<div class="wrap">
	<input name='zkn_orders[old_status]' type='hidden' id='old_status' class='regular-text' />
	<input name='zkn_orders[new_status]' type='hidden' id='new_status' class='regular-text' />
	<input name='zkn_orders[selected_orders]' type='hidden' id='selected_orders' class='regular-text' />

<?PHP 
// Show orders separated by status ('Received', 'In the Print Lab', 'Shipped').  For Shipped, orders are filtered by year/month.

	$order_table 	= $wpdb->prefix."zkn_orders";
	$customer_table = $wpdb->prefix."zkn_customers";
	$invoice 		= $_GET['invoice'];
	
	if (!empty($invoice))
	{
		include(WP_PLUGIN_DIR . '/Zekken_Cart/zkn_1order_page.php');
	}
	else
	{	
		// First, update status.
		if (isset($_GET['settings-updated']))
		{
			$options = get_option('zkn_orders');			

		 	$current_status	= $options['old_status'];	
		 	$new_status		= $options['new_status'];
			$invoices		= $options['selected_orders'];
			
			$query = "UPDATE `" . $order_table . "` SET `status` = '" . $new_status . "' WHERE `status` = '" . $current_status . "' AND `invoice` IN (" . $invoices . ")";

			$wpdb->query($query);
			
			// Notify the user that updating (or adding) has been done.
			echo '<div id="message" class="updated fade"><p><strong>';
			_e('Order(s) updated');
			echo '</strong></p></div>';
			
			// Empty the product stored in the option table.
			update_option('zkn_order_options', '');
		}
	
		echo "<h2>"; _e('Orders'); echo "</h2>";

		echo "<form method='post' action='options.php' name='OrderPage'>";
		
		settings_fields('zkn_order_options');
		do_settings_fields('zkn_order_options', 'default');
		do_settings_sections('zkn_order_options');

		// When the user chooses a certain year/month, GET shows it.  When this page is displayed from somewhere else other than this page itself, then the default is nothing. 
		$selected_year_month = $_GET['selected_year_month'];
			
		$period = "";
		
		$status = array('Received', 'In the Print Lab', 'Shipped');
		$textColor = "#000000";
		
		$current_month 	= date("n");
		$current_year 	= date("Y");
	
		$selected_year 	= 0;
		$selected_month = 0;
			
		if (!empty($selected_year_month) && $selected_year_month != "Show All")
		{
		    $selected_year = date("Y", $selected_year_month);
		    $selected_month = date("m", $selected_year_month);
	
			$next_month = mktime(0, 0, 0, date("m", $selected_year_month) + 1, 1, date("Y", $selected_year_month));
			$end_year = date("Y", $next_month);
			$end_month = date("m", $next_month);
	
			$period = "AND (`" . $order_table . "`.`order time` >= '" . $selected_year . "-" . $selected_month . "-01 00:00:00' AND `" . $order_table . "`.`order time` < '" . $end_year . "-" . $end_month . "-01 00:00:00')"; 
		}
		else if ($selected_year_month == "Show All")
		{
			// Chose only the order date is valid
			$period = "AND (`$order_table`.`order time` <> '' AND `$order_table`.`order time` <> '0000-00-00 00:00:00')";
		}
		// Empty -> Choose current Month
		else
		{
			$next_month = mktime(0, 0, 0, date("m") + 1, 1, date("Y"));
			$end_year = date("Y", $next_month);
			$end_month = date("m", $next_month);
	
			$period = "AND (`" . $order_table. "`.`order time` >= '" . $current_year. "-" . $current_month . "-01' AND `" . $order_table . "`.`order time` < '" . $end_year-$end_month . "-01')"; 
	
			$selected_year 	= $current_year;
			$selected_month = $current_month;
			
			$selected_year_month = mktime(0, 0, 0, date("m"), 1, date("Y"));
		}
		
		// Get the oldest order's year and month.
		$oldest_order_time =  $wpdb->get_var("SELECT `order time` FROM `" . $order_table . "` WHERE `order time` <> '' AND `order time` <> '0000-00-00 00:00:00' ORDER BY `order time` LIMIT 1");
		
		// This is an integer number.
		$oldest_order_month = 0;
		
		if ($oldest_order_time)
		{
			$pieces = explode("-", $oldest_order_time);
			$oldest_order_month =  mktime(0, 0, 0, $pieces[1], 1, $pieces[0]); 
		}
		else
		{
			$oldest_order_month = mktime(0, 0, 0, date("m"), 1, date("Y"));
		}
		
		$query 		= "";
		$style 		= "";
		$check_box 	= "";
		$subtotal 	= 0;
		
		// Opix orders.ID must be 419 or higher 
		for ($i = 0; $i < count($status); $i += 1) 
		{
			$status_text = $status[$i];
			
			# Create a SQL statement
			#  $sc_mysql_race_table  case sensitive!
			
			if ($status_text == "Shipped")
			{
				$query = "SELECT `". $order_table . "`.`order time`, `" . $order_table . "`.`invoice`, `" . $order_table . "`.`status`, `" . $customer_table . "`.`first name`, `" . $customer_table . "`.`last name`, `" . $order_table . "`.`shipping method`, `" . $order_table . "`.`ship_first_name`, `" . $order_table . "`.`ship_last_name`, `" . $order_table . "`.`subtotal` FROM `" . $order_table . "`, `" . $customer_table . "` WHERE `" . $customer_table . "`.`ID` = `" . $order_table . "`.`customer ID` AND (`" . $order_table . "`.`status` = '" . $status_text . "' OR `" . $order_table . "`.`status` = 'Voided') " . $period . " ORDER BY `" . $order_table . "`.`order time` DESC";
			}
			else
			{
				$query = "SELECT `" . $order_table . "`.`order time`, `" . $order_table . "`.`invoice`, `" . $order_table . "`.`status`, `" . $customer_table . "`.`first name`, `" . $customer_table . "`.`last name`, `" . $order_table . "`.`shipping method`, `" . $order_table . "`.`ship_first_name`, `" . $order_table . "`.`ship_last_name`, `" . $order_table . "`.`subtotal` FROM `" . $order_table . "`, `" . $customer_table . "` WHERE `" . $customer_table . "`.`ID` = `" . $order_table . "`.`customer ID` AND `" . $order_table . "`.`status` = '" . $status_text . "' ORDER BY `" . $order_table . "`.`order time` DESC";
			}
		
			$orders = $wpdb->get_results($query, ARRAY_N); 
	
			echo "<h3>" . $status_text;
				
			// For Status = Shipped, show a combobox next to the text.  The combo is used to filter shipped orders by year-month, like 2010 January, 2009 December, etc.  
			// The top is Show All, which means no filter.
			// Default is current year and month.				
			if ($status_text == "Shipped")
			{
				$month_name = "";
	
				echo "&nbsp; <select size='1' name='selected_year_month' onchange='location.href='admin.php?page=zkn_order_page.php&selected_year_month=' + this.options[this.selectedIndex].value'>
							<OPTION 
				";
					
				if ($selected_year_month == "Show All")
				{
					echo " SELECTED ";				
				}
							
				echo " value='Show All'>Show All</OPTION>";
				
				$current_year_month  = mktime(0, 0, 0, date("m"), 1, date("Y"));
	
				do
				{
					$month_name = date("F", $current_year_month);
					$current_year = date("Y", $current_year_month);
					
					echo " <OPTION ";
	
					if ($selected_year_month == $current_year_month)
					{
						echo "SELECTED ";
					}
					
					echo " value='" . $current_year_month . "'>" . $current_year . " " . $month_name . "</OPTION>";
					
					// Decrement by 1 month.
					$current_year_month  = mktime(0, 0, 0, date("m", $current_year_month) - 1, 1, date("Y", $current_year_month));
				}
				while ($oldest_order_month <= $current_year_month); 
				
				echo "</select>";
			}
			else
			{
				echo "<p class='submit'>";
				
				// There are 2 buttons for the status Received: To Lab and To Sent. 
				if ($status_text != "In the Print Lab")
					echo "<input type='submit' id='Received_To_Lab' name='Received_To_Lab' class='button-primary' value='Move to In the Print Lab' onClick='return checkData(this.id);' />&nbsp;&nbsp;<input type='submit' id='Received_To_Shipped' name='Received_To_Shipped' class='button-primary' value='Move to Shipped' onClick='return checkData(this.id);' /></p>";
				else
					echo "<input type='submit' id='Lab_To_Shipped' name='Lab_To_Shipped' class='button-primary' value='Move to Shipped' onClick='return checkData(this.id);' /></p>";
			}					
								
			echo "</h3><table class='widefat tag fixed' cellspacing='0'>
				<thead>
					<tr>";
					print_column_headers('Orders');
			echo "</tr>
				</thead>";
		
			$textColor 	= "#000000";
			$counter 	= 0;
			$subtotal 	= 0;
			
			// Each shipping method has its own color.  So the faster ones get attention soon.
			foreach ($orders as $row)  
			{
				$style = ('class="alternate"' == $style || 'class="alternate active"' == $style) ? '' : 'alternate';
	
				if ($style != '')
					$style = 'class="' . $style . '"';
	
				if ($row[5] == "Next Day")
				{
					// Red
					$textColor = "#FF0000";
				}
				else if ($row[5] == "Two Day")
				{
					// Red
					$textColor = "#FF00FF";
				}
				else if ($row[5] == "Priority")
				{
					// Red
					$textColor = "#0000FF";
				}
				else
				{
					// black
					$textColor = "#000000";
				}
				
				// For orders already shipped, checkboxes are not 
				if ($status_text != "Shipped")
					$check_box = "<input type='checkbox' id='" . $row[1] . "' value='" . $row[1] . "'/>";
				else
					$check_box = "&nbsp;"; 		 
				
				echo "<tr " . $style . ">
										<td>" . $check_box . "</td>
										<td>" . $row[0] . "</td>
										<td><a href='admin.php?page=zkn_order_page.php&invoice=" . $row[1] . "' style='text-decoration: none'>" . $row[1] . "</a></td>
										<td><font color='" . $textColor . "'>" . $row[3] ." " . $row[4] . "</font></td>
										<td><font color='" . $textColor . "'>" . $row[6] . " " . $row[7] . "</font></td>
										<td>" . $row[5] . "</td>
				            		</tr>";
				$counter++;
				$subtotal += $row[8];
			}
			
			// Show how many orders of each status are.
			echo "<tr>
					<td colspan='6'>
								<p align='right'><b>Total: " . $counter . " (\$" . $subtotal . " - not including shipping / tax)</font></b></P>
							</td>
						</tr>
				</table>";
		}
		echo "</FORM>";
	}
?>
</DIV>
