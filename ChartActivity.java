package net.opix.Gemini;

import android.support.v4.widget.SwipeRefreshLayout;
import android.os.Bundle;
import android.support.v7.app.AppCompatActivity;
import android.widget.Toast;

import com.android.volley.Response;
import com.android.volley.VolleyError;
import com.android.volley.toolbox.JsonArrayRequest;
import com.github.mikephil.charting.charts.HorizontalBarChart;
import com.github.mikephil.charting.components.Legend;
import com.github.mikephil.charting.data.BarData;
import com.github.mikephil.charting.data.BarDataSet;
import com.github.mikephil.charting.data.BarEntry;
import com.github.mikephil.charting.components.XAxis;
import com.github.mikephil.charting.components.YAxis;
import com.github.mikephil.charting.components.XAxis.XAxisPosition;
import com.github.mikephil.charting.components.Description;

import org.json.JSONArray;
import org.json.JSONException;

import java.util.ArrayList;
import net.opix.Gemini.GeminiXAxisFormatter;
import net.opix.Gemini.GeminiYAxisFormatter;

public class ChartActivity extends AppCompatActivity implements SwipeRefreshLayout.OnRefreshListener {

    private SwipeRefreshLayout swipeRefreshLayout;
    private String       selectedTable;
    private int          selectedType;

    private final int TYPE_DIVISION = 0;
    private final int TYPE_FINISHERS = 1;

    private ArrayList<BarEntry> yAxis   = new ArrayList<>();
    private HorizontalBarChart barChart = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.gemini_chart_layout);

        barChart = (HorizontalBarChart) findViewById(R.id.chart);
        barChart.setExtraTopOffset(10);
        barChart.setExtraBottomOffset(10);
        Legend leg = barChart.getLegend();
        leg.setXEntrySpace(4);
        leg.setYOffset(10);
        leg.setFormSize(8);
        leg.setTextSize(16);

        Description desc = new Description();
        desc.setText("");
        barChart.setDescription(desc);

        YAxis rightAxis = barChart.getAxisRight();
        rightAxis.setDrawAxisLine(true);
        rightAxis.setDrawGridLines(false);
        rightAxis.setTextSize(16);

        YAxis leftAxis = barChart.getAxisLeft();
        leftAxis.setDrawAxisLine(true);
        leftAxis.setDrawGridLines(true);
        leftAxis.setTextSize(16);

        XAxis xAxis = barChart.getXAxis();
        xAxis.setPosition(XAxisPosition.BOTTOM);
        xAxis.setTextSize(16f);
        xAxis.setDrawAxisLine(false);
        xAxis.setDrawGridLines(false);
        xAxis.setXOffset(10);

        getSupportActionBar().setDisplayHomeAsUpEnabled(true);
        getSupportActionBar().setHomeAsUpIndicator(R.mipmap.ic_launcher_reversed);

        selectedTable       = getIntent().getStringExtra("gemini_selected_table_name");
        selectedType        = getIntent().getIntExtra("gemini_selected_type", 0);

        setTitle(selectedType == TYPE_FINISHERS ? "By Finish Time" : "By Division");

        swipeRefreshLayout = (SwipeRefreshLayout) findViewById(R.id.swipe_refresh_layout);

        swipeRefreshLayout.setOnRefreshListener(this);

        swipeRefreshLayout.post(new Runnable() {
                                    @Override
                                    public void run() {
                                        swipeRefreshLayout.setRefreshing(true);

                                        fetchChart();
                                    }
                                }
        );
    }

    @Override
    public void onRefresh() {
        fetchChart();
    }

    private void fetchChart()
    {
        // showing refresh animation before making http call
        swipeRefreshLayout.setRefreshing(true);

        // Default = TYPE_FINISHERS
        String url = "https://gemininext.com/mobile/?action=16&table=" + selectedTable;

        if (TYPE_DIVISION == selectedType)
            url = "https://gemininext.com/mobile/?action=15&table=" + selectedTable;

        JsonArrayRequest req = new JsonArrayRequest(url,
                new Response.Listener<JSONArray>() {
                    @Override
                    public void onResponse(JSONArray jArray) {

                        if (jArray.length() > 0) {
                            String[] xArray = new String[jArray.length()];

                            try {
                                for (int j = 0; j < jArray.length(); j++) {
                                    JSONArray jArrayHeader  = jArray.getJSONArray(j);

                                    if (TYPE_DIVISION != selectedType)
                                        xArray[j] = formatXValue((String)jArrayHeader.get(0));
                                    else
                                        xArray[j] = (String)jArrayHeader.get(0);

                                    yAxis.add(new BarEntry(j, Integer.parseInt((String)jArrayHeader.get(1))));
                                }

                                BarDataSet dataSet = new BarDataSet(yAxis, "Number of Participants");
                                dataSet.setValueFormatter(new GeminiYAxisFormatter());
                                BarData data = new BarData(dataSet);

                                XAxis barAxis = barChart.getXAxis();
                                barAxis.setLabelCount(jArray.length());
                                barAxis.setValueFormatter(new GeminiXAxisFormatter(xArray));
                                barChart.setData(data);
                                barChart.animateY(5000);

                            } catch (JSONException e) {
                            }
                        }
                        // stopping swipe refresh
                        swipeRefreshLayout.setRefreshing(false);
                    }
                }, new Response.ErrorListener() {
            @Override
            public void onErrorResponse(VolleyError error) {

                 Toast.makeText(getApplicationContext(), error.getMessage(), Toast.LENGTH_LONG).show();

                // stopping swipe refresh
                swipeRefreshLayout.setRefreshing(false);
            }
        });
        // Adding request to request queue
        GeminiApplication.getInstance().addToRequestQueue(req);
    }

    private String formatXValue(String xValue) //HH:mm:ss
    {
        String[] stringArray = xValue.split(":");

        int hours = Integer.parseInt(stringArray[0]);
        int minutes = Integer.parseInt(stringArray[1]);

        if (minutes >= 50)
        {
            hours++;
            minutes = 0;
        }
        else
        {
            minutes += 10;
            minutes = (minutes / 10) * 10;
        }

        return String.format("%dh%02dm >", hours, minutes);
    }
}