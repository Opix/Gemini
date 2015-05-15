/*
	References:
	
	1) https://code.google.com/p/jquery-csv/
	2) Updating URL:
	https://developer.mozilla.org/en-US/docs/Web/Guide/API/DOM/Manipulating_the_browser_history
*/

jQuery(document).ready(function()
{
	var worker;
	var timer_worker;

	// Create a new sub race.
	// Need
	// 1) Type (triathlon, duathlon, 5k, etc.)
	// 2) Description (optional)
	// 3) .csv file
	// 4) Check columns
	
	// Send the info above
		
	// After received success,
	// 1) Update the column -> text
	// 2) Update the tab like "Triathlon (88)"
	// 3) Add a new tab with +
	
    var progressbar = jQuery("#progressbar");
	var progressLabel = jQuery("#progress-label");
 
 	progressLabel.hide();
	progressbar.hide();
 
	progressbar.progressbar({
		// value: false,
		
		change: function() {
		
			var max_records = progressbar.progressbar("option", "max");
			progressLabel.text( progressbar.progressbar("option", "value") + " / " + max_records);//.delay(500);
		},
		
		complete: function() {
		}
	});
	
// Handling buttons. 
 	jQuery('.grr_button-primary').click(function(event)
	{
		event.preventDefault();

   		var active_tab 	= jQuery("ul.easytabs li.active");
		var active_tab_id 		= active_tab.attr('id');
		var subrace_name = jQuery('#tab' + active_tab_id + '_subrace_table').val();
		// What button was pressed?  Update or Delete?
		var button_type = jQuery(this).attr('Name');
		
		// Auto-update
		if (button_type == 'Update_start')
		{
			var frequency 		= jQuery('#file_from_server_frequency').val(); // seconds
			var duration 		= jQuery('#file_from_server_duration').val();	// hours 
			var worker_path 	= jQuery('#grr_worker_js_path').val();
			var admin_ajax_php 	= jQuery('#admin_ajax_php').val();
			
			if (frequency == '0' || frequency == '')
			{
				alert('"every [ ] seconds" can not be 0 or blank');
				return;
			}
			
			if (duration == '0' || duration == '')
			{
				alert('"for the next [ ] hours" can not be 0 or blank');
				return;
			}
			
			// Determine when this auto-updating should stop.  Milliseconds x 1000 = 1 second.
			var count  	= (duration * 60 * 60) / frequency;
			
			if ((duration * 60 * 60) % frequency != 0)
				count++;
				
			jQuery(this).prop("disabled",true);

			if (typeof(SharedWorker) !== "undefined") 
			{
        		if (typeof(worker) == "undefined") 
            		worker = new SharedWorker(worker_path + "/grr_auto_upload.js");

				if (typeof(timer_worker) == "undefined") 
					timer_worker = new SharedWorker(worker_path + "/grr_timer.js");
									
        		worker.port.onmessage = function(event) {
        		
        			var tab 		= event.data[0];
        			var tempo		= event.data[1];
 
					var response_array = JSON.parse(tempo);

					// GeminiRaceResults/5K_twolf_results_1.csv
           			//jQuery('#upload_status').val("Uploaded " + response_array.success  + " records.");
					console.log("Uploaded " + response_array.success  + " records.");
					
					var race_type = jQuery('#tab' + tab +'_race_type :selected').text(); // ID of Subrace (Triathlon, Half marathon, etc.)			

					race_type += ' (' + response_array.new_total + ')';
					jQuery('#tab' + tab + '_title').text(race_type);
					// GeminiRaceResults/Harding_TT_Results_2_2015_1.csv
            	};
    			worker.port.onerror = function(error) {
					console.log(' Error Caused by worker: '+ error.filename + ' at line number: ' + error.lineno + ' Detailed Message: '+error.message);
					jQuery('#upload_status').val(' Error Caused by worker: '+ error.filename + ' at line number: ' + error.lineno + ' Detailed Message: '+error.message);
    			};

				// Timer
    			timer_worker.port.onerror = function(error) {
					console.log(' Error Caused by worker: '+ error.filename + ' at line number: ' + error.lineno + ' Detailed Message: '+error.message);
					jQuery('#upload_status').val(' Error Caused by worker: '+ error.filename + ' at line number: ' + error.lineno + ' Detailed Message: '+error.message);
    			};

				// WHy is this expecting 2 pieces of data?   event.data simply should show a number, but instead showing ",1", ",2", etc...?
				timer_worker.port.onmessage = function(event) {
       				jQuery('#upload_status').val(event.data); //5K_twolf_results.csv
    			};
				
				// Timer
         		timer_worker.port.start();
        		
				timer_worker.port.postMessage([frequency,count]);
				
				// Loop through each tab.  Ignore the last one (+).
				var tabs = jQuery("ul.easytabs li");
					tabs.each(function(li) {
			
					var tab_id 		= jQuery(this).attr('id');
					
					// If Tab ID == 0, that means the last one.
					if (tab_id != '0')
					{
						var csv_File	= jQuery('#file_from_server' + tab_id).val();
						
						if (csv_File != '')
						{
							var subrace_table = jQuery('#tab' + tab_id + '_subrace_table').val();
	
			 				worker.port.start();
			 				
			 				// Send tab ID to store.  When the worker responds, the correct tab is updated.
							worker.port.postMessage([admin_ajax_php, csv_File, subrace_table, frequency, count, tab_id]);
							
	   						// console.log();
   					
   							// Wait 2 seconds before going to the next tab.
   							setTimeout(function(){ //do what you need here
							}, 2000);
	   					}
   					}
				});
				
				// Enable the stop button.
				jQuery('#file_from_server_stop').prop("disabled", false);
    		} else {
        		alert("Sorry! No Web Worker support.");
    		}
		}
		
		else if (button_type == 'Update_stop')
		{
			if (typeof(SharedWorker) !== "undefined") 
			{
				timer_worker.port.close();
				timer_worker = undefined;
				worker.port.close();
				worker = undefined;
			}			
			// Disable the stop button.
			jQuery(this).prop("disabled",true);
			
				// Enable the start button.
			jQuery('#file_from_server_start').prop("disabled", false);
		}
		else
			return true;
  	});
  
 	function grr_update_1_subrace(active_tab_id, subrace_table)
	{		
		progressLabel.show();
		progressbar.show();
		
		// Intermediate state.  Since the whole .csv is passed, there is no way of showing how many records have been added.
		progressbar.progressbar("option", "value", false);
		
		var element_id 		= '#tab' + active_tab_id + '_column_count';
		var column_total 	= jQuery(element_id).val();		// Number of columns 
		var master_table_column_array = '';

		element_id = '#tab' + active_tab_id + '_descriptions';
	
		var race_descriptions = jQuery(element_id).val();

		element_id = '#tab' + active_tab_id + '_race_type';
					
		var race_type 		= jQuery(element_id).val(); // ID of Subrace (Triathlon, Half marathon, etc.)			
		var column_array = '';
		// Go through all of drop-down lists and get value of each selection.
		for (var i = 0; i < column_total; i++)
		{
			var column_id = 'tab' + active_tab_id + '_col' + (i + 1) + '_display';
			var selected = jQuery('input[name=' + column_id + ']:checked').val();

			if (selected != '0')
			{
				if (master_table_column_array != '')
					master_table_column_array += ',';
					
				master_table_column_array += selected;
			}
		}

		jQuery.ajax({
			url: grrAdminAjax.ajaxurl,
			type:'POST',
			dataType: 'json',
			data: {action: 'grr_update_subrace', subrace_id: active_tab_id, race_type_id: race_type, description: race_descriptions, display_columns: master_table_column_array}, 
			grr_admin_nonce : grrAdminAjax.grr_admin_nonce,
			
			success:function(results, status)
			{
				progressLabel.text("Successfully updated.");
			}
		});
			
		element_id = '#tab' + active_tab_id + '_tempo_csv_storage';
		
		var csv_File = jQuery(element_id).val();
 		  		
		// Call ajax and get a new header      							
		jQuery.ajax({
			url: grrAdminAjax.ajaxurl,
			type:'POST',
			dataType: 'json',
			data: {action: 'grr_insert_all_csv', csvFile: csv_File, table: subrace_table, overall: '1', ignoredFields: ''}, 
			grr_admin_nonce : grrAdminAjax.grr_admin_nonce,
			
			success:function(results, status)
			{
				if (results.failure != '')
					alert(results.failure);
				
				progressLabel.text("Complete!  Total number of records: " + results.success);
				
				// Update tab title with the number of records.
				var race_type = jQuery('#tab' + active_tab_id +'_race_type :selected').text(); // ID of Subrace (Triathlon, Half marathon, etc.)			
		
				jQuery('#tab' + active_tab_id + '_title').text(race_type + ' (' + results.success + ')');
			}
		});
		progressLabel.hide();
		progressbar.hide();
  	}
 	 	
 	// http://stackoverflow.com/questions/23402187/multiple-files-upload-and-using-file-reader-to-preview
  	jQuery('.csvFile').change(function(e)
  	{ // "input:file"
   		var reader = new FileReader();
   		
   		reader.onload = function()
   		{
			var data = reader.result;
      			
			var result = jQuery.csv.toArrays(data);
      		      		
      		// var tab_count = jQuery("ul.easytabs li").length;
      		
      		var active_tab = jQuery("ul.easytabs li.active");
		
			var tab_id = active_tab.attr('id');

			if (tab_id == 0)
			{
  				jQuery('#grr_tab0_column_row').empty();

				// Call ajax and get a new header      				
  				jQuery.ajax({
					url: grrAdminAjax.ajaxurl,
					type:'POST',
					dataType: 'json',
					data: {action: 'grr_generate_header', header: result[0].toString()}, // result[0] is still an array so it has to be converted to string "A,B,C,..."
					grr_admin_nonce : grrAdminAjax.grr_admin_nonce,
					
					success:function(results, status)
					{
						jQuery('#grr_tab0_column_row').append(results.rows);

						// Update column count
						var element_id = '#tab0_column_count';
						jQuery(element_id).val(result[0].length);
					}
				});
			}
			
			// Store the whole data in the hidden temporary space.  Use later.
			element_id = '#tab' + tab_id + '_tempo_csv_storage';
			jQuery(element_id).val(data);
   		};
   		reader.readAsText(this.files[0]);
	});	
});