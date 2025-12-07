# FUTURE_DS_01
Data Science & Analytics Internship  Task1
Superstore Business Insights – Power BI Project

This project transforms the classic Superstore dataset into a complete end-to-end analytics solution. The objective was to take raw sales data, clean it using SQL, model it properly, build optimized DAX measures, and design a clear, modern Power BI report that delivers real business insights — not just pretty visuals.

Data Preparation (MySQL)

All tables were cleaned and prepared using MySQL.
Key tasks included:

• Standardizing date fields
• Splitting the model into fact and dimension tables
• Creating the calendar table
• Customer and product categorization
• Fixing missing or inconsistent values
• Preparing all metrics needed for Power BI
• Ensuring the model follows a correct star schema

This step ensured Power BI receives clean, structured data ready for fast calculation.

Data Model

A simple star schema was used for maximum performance.
One fact table contains all orders and sales activity.
Dimensions include customers, products, regions, and a full calendar table to support time intelligence.

DAX Measures

All KPIs in the report were built using optimized DAX code:

• Total Sales
• Total Profit
• Profit Margin %
• Total Orders
• Quantity Sold
• Year-over-Year Growth
• Last 3-Month trend measures
• Customer lifecycle measures (New, Returning, Loyal, Lost)

Time intelligence was handled using DATEADD, SAMEPERIODLASTYEAR and EOMONTH to ensure correct monthly and yearly comparisons.

Dashboard Design

The report layout is clean, with soft colors, clear spacing and simple navigation.
The design includes:

• KPI cards
• Customer segmentation donut chart
• Category slicers
• Regional filters
• Annual customer dynamics visual
• Monthly revenue and profit trend
• YoY growth indicator
• Clean page navigation buttons

Everything is grouped in a way that communicates insights quickly.

Main Insights

Revenue reached 2.3M, with 286K profit and a 12.47% margin.
YoY performance year to year

Customer breakdown shows the business is mainly retail-driven:
• Consumer segment accounts for more than half of total revenue
• Corporate customers are secondary
• Home Office segment is the smallest

Customer lifecycle analysis shows new customers are growing but loyal customers are declining.
This means acquisition is strong, but long-term retention needs improvement.

Category analysis shows Technology drives growth, while Furniture has inconsistent margin and Office Supplies depend on volume.

Monthly trends show that Q4 has the strongest movement, while profits remain flatter across the year. This indicates discount pressure or margin inefficiencies.

Business Impact

This dashboard helps identify:

• The real drivers of revenue
• Where profitability is leaking
• Which customer groups need attention
• Which product categories deserve investment
• How demand behaves throughout the year
• Which regions perform better or weaker

The insights support decisions in pricing, inventory planning, customer retention and marketing.

Repository Structure

📦 Superstore-PowerBI-Project
├─ 📁 Power_BI   (dashboard + .pbix file)
├─ 📁 Data      (raw data)
├─ 📁 sql   (MySQL queries)
├─ README.md    (this file)



How to Use the Report

Download the .pbix file and open it in Power BI Desktop.
All visuals, filters and insights are fully interactive.

