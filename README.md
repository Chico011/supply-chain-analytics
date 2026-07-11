# 🚚 Supply Chain Delivery Performance & Operational Efficiency Analysis

End to end SQL Server, Python, and Power BI project analyzing 18,000 supply chain shipments to identify delivery delays, supplier performance, warehouse bottlenecks, and operational cost drivers.

---

## 📊 Dashboard Preview

### Dashboard Overview 1

![Dashboard Overview 1](Screenshot.dashboard%20overview1.png)

### Dashboard Overview 2

![Dashboard Overview 2](Screenshot.dashboard%20overview2.png)

---

## 📌 Project Overview

This project analyzes delivery performance across a regional supply chain using SQL Server and Power BI.

The company has a **29% shipment delay rate** but no visibility into whether delays are caused by suppliers, carriers, warehouses, or transportation routes.

Using a six table data warehouse built in SQL Server, this project cleans the data, analyzes operational performance, and builds interactive dashboards to identify the main causes of delays and their financial impact.

The goal is to provide clear insights and practical recommendations that help improve delivery performance and reduce operational costs.

---

## 🎯 Business Problem

| Item | Description |
|------|-------------|
| **Problem** | Around 29% of shipments arrive late. |
| **Challenge** | The business does not know whether suppliers, carriers, warehouses, or routes are causing the delays. |
| **Business Impact** | Rising costs, delayed deliveries, and contracts at risk. |
| **Goal** | Identify the causes of delays and recommend actions to improve performance. |

---

## 🛠️ Tools & Technologies

- SQL Server (SSMS)
- T SQL
- Python
- Power BI
- CSV Files
- Git & GitHub

---

## 📂 Project Structure

```
supply-chain-analytics/

datasets/
    csv-files/
        sc.ref_suppliers.csv
        sc.ref_carriers.csv
        sc.ref_routes.csv
        sc.ref_warehouses.csv
        sc.ref_products.csv
        sc.fact_shipments.csv

scripts/
    00_supply_chain_setup.sql
    01_database_exploration.sql
    02_network_overview.sql
    03_shipment_date_analysis.sql
    04_volume_cost_distribution.sql
    05_core_metrics_analysis.sql
    06_data_cleaning.sql
    07_ranking_analysis.sql
    08_change_over_time_analysis.sql
    09_cumulative_analysis.sql
    10_performance_analysis.sql
    11_data_segmentation.sql
    12_part_to_whole_analysis.sql
    13_report_suppliers.sql
    14_report_shipments.sql

README.md
LICENSE
supply_chain_dashboard.pbix
```

---

## 🗄️ Database Schema

```
SupplyChainDW

ref_suppliers
ref_carriers
ref_routes
ref_warehouses
ref_products
fact_shipments
```

The project uses a six table star schema with **18,000 shipment records**.

The fact table stores shipment transactions while the reference tables provide supplier, carrier, warehouse, route, and product information.

---

## 🧹 Data Cleaning

The dataset was intentionally created with common data quality issues to simulate a real business environment.

The cleaning process included:

- Removing null and blank values
- Standardizing inconsistent text values
- Correcting missing delay calculations
- Flagging invalid shipment dates
- Validating the final dataset before analysis

All cleaning was completed in SQL Server before any reporting or dashboard development.

---

## 📈 SQL Analysis

The project includes **15 SQL scripts** covering:

- Database setup
- Data exploration
- Data cleaning
- KPI calculations
- Ranking analysis
- Time based analysis
- Performance analysis
- Data segmentation
- Report views for Power BI

---

## 📊 Dashboard Features

The Power BI dashboard includes:

- Executive KPI summary
- Supplier performance scorecards
- Carrier performance analysis
- Warehouse bottleneck analysis
- Route performance analysis
- Delay severity analysis
- Financial impact of shipment delays
- Interactive filters and drill through

---

## 💡 Key Findings

- Around **29%** of shipments arrive late across all regions.
- The delay problem is consistent over three years, indicating a structural issue rather than a seasonal one.
- Some Gold and Platinum suppliers perform worse than lower contract tiers.
- Mumbai Port Warehouse operates at **104% capacity**, making it one of the largest operational bottlenecks.
- Critical delays account for **$23.3M** of the **$53.2M** total delay cost.
- Several carriers fail to meet their contracted on time delivery targets.

---

## ✅ Recommendations

- Review suppliers with delay rates above 40%.
- Reduce warehouse overload by redistributing shipment volumes.
- Monitor carrier performance against contracted service levels.
- Prioritize high value shipments with reliable carriers.
- Implement monthly supplier performance scorecards.

---

## 💻 SQL Skills Demonstrated

- SQL Joins
- Common Table Expressions (CTEs)
- Window Functions
- CASE Statements
- Aggregate Functions
- Date Functions
- Ranking Functions
- Data Cleaning
- Data Validation
- Data Modeling
- Business Analysis

---

## 📈 Business Value

This project demonstrates how SQL Server and Power BI can be used to transform raw operational data into business insights.

The analysis helps decision makers identify the root causes of shipment delays, measure their financial impact, and make informed decisions to improve supply chain performance.

---

## 👤 About Me

Hi, I'm **Collins Odoh**, a Computer and Information Systems student at **BYU Pathway Worldwide** with a growing interest in Data Analytics and Business Intelligence.

I enjoy building end to end analytics projects that combine SQL, Python, and Power BI to solve real business problems and turn raw data into actionable insights.

📎 LinkedIn: https://www.linkedin.com/in/collins-odoh-97b497382

---

## 📄 License

This project is licensed under the MIT License. 
