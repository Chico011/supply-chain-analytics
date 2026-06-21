# 🚚 Supply Chain Delivery Performance & Operational Efficiency Analysis

> An advanced end-to-end SQL analytics project built on a custom supply chain data warehouse — diagnosing delivery failures, supplier underperformance, carrier inefficiencies, and warehouse bottlenecks across a regional distribution network.

---

## 📌 Project Overview

This project tackles a real operational problem that costs businesses contracts and revenue every day — late shipments with no visibility into why they happen or where to fix them.

A regional distribution company is experiencing a **~29% shipment delay rate** across its network. Leadership has no data-driven answer to whether delays are caused by underperforming suppliers, unreliable carriers, overloaded warehouses, or specific routes. Without that visibility, every decision is a guess.

This project delivers that visibility. Using a six-table star schema data warehouse built in SQL Server, it covers the full analytics lifecycle — from raw data ingestion and dirty data cleaning, through deep operational analysis, all the way to structured performance report views that Power BI connects to directly.

The goal is not just to describe what is happening — it is to diagnose **why**, quantify the **financial exposure**, and deliver **actionable recommendations** the operations team can act on immediately.

---

## 🔍 Business Problem

| | |
|---|---|
| **Problem** | ~29% of shipments arrive late but the business has no visibility into the root cause |
| **Business stake** | Contract renewals at risk, rising operational costs, no data to justify intervention |
| **Primary question** | Where exactly are delays happening — suppliers, carriers, routes, or warehouses? |
| **Secondary question** | Which entities are the worst performers and what is the financial cost of their failures? |
| **Success metric** | On-time delivery rate, average delay days, cost of delayed shipments, supplier delay ranking |

---

## 🗂️ Database Schema

```
SupplyChainDW
 [sc]
   > sc.ref_suppliers     — Supplier profiles, categories, contract tiers, ratings
   > sc.ref_carriers      — Carrier details, transport modes, contracted OTD rates
   > sc.ref_routes        — Origin-destination lanes, distances, expected transit times
   > sc.ref_warehouses    — Warehouse locations, capacity, current load, processing times
   > sc.ref_products      — Product catalogue, categories, weight, fragility, value
   > sc.fact_shipments    — Core fact table — one row per shipment (18,000 rows)
```

**Relationships:**
```
sc.ref_suppliers ─────────┐
sc.ref_carriers  ─────────┤
sc.ref_routes    ─────────┼──► sc.fact_shipments
sc.ref_warehouses ────────┤
sc.ref_products  ─────────┘
```

---

## 📁 Repository Structure

```
supply-chain-analytics/
 [datasets]
   [csv-files]
     > sc.ref_suppliers.csv
     > sc.ref_carriers.csv
     > sc.ref_routes.csv
     > sc.ref_warehouses.csv
     > sc.ref_products.csv
     > sc.fact_shipments.csv
 [scripts]
     > 00_supply_chain_setup.sql
     > 01_database_exploration.sql
     > 02_network_overview.sql
     > 03_shipment_date_analysis.sql
     > 04_volume_cost_distribution.sql
     > 05_core_metrics_analysis.sql
     > 06_data_cleaning.sql
     > 07_ranking_analysis.sql
     > 08_change_over_time_analysis.sql
     > 09_cumulative_analysis.sql
     > 10_performance_analysis.sql
     > 11_data_segmentation.sql
     > 12_part_to_whole_analysis.sql
     > 13_report_suppliers.sql
     > 14_report_shipments.sql
 > LICENSE
 > README.md
```

---

## 📊 What Each Script Does

| # | Script | Description |
|---|--------|-------------|
| 00 | `supply_chain_setup` | Creates the database, schema, all six tables and bulk loads CSV data with TRY/CATCH error handling |
| 01 | `database_exploration` | Explores table structures, column details, data types and confirms row counts after loading |
| 02 | `network_overview` | Examines distinct values across all reference tables and flags early dirty data signals |
| 03 | `shipment_date_analysis` | Identifies time spans, measures promised vs actual transit gaps, and flags impossible date records |
| 04 | `volume_cost_distribution` | Analyses how shipment volume, cost, and delays are distributed across every network dimension |
| 05 | `core_metrics_analysis` | Computes all headline KPIs — OTD rate, avg delay days, total network cost, active suppliers |
| 06 | `data_cleaning` | Full audit, cleaning, and validation of all six tables — nulls, blanks, casing, and delay recalculation |
| 07 | `ranking_analysis` | Ranks suppliers, carriers, routes, and warehouses by delay rate and cost efficiency |
| 08 | `change_over_time_analysis` | Tracks delay rates, costs, and volume trends monthly, quarterly, and annually |
| 09 | `cumulative_analysis` | Calculates running totals, rolling averages, and cumulative cost of delays over time |
| 10 | `performance_analysis` | Year-over-year benchmarking for every supplier, carrier, route region, and warehouse |
| 11 | `data_segmentation` | Classifies suppliers, shipments, routes, and warehouses into operational performance tiers |
| 12 | `part_to_whole_analysis` | Measures each dimension's percentage contribution to total volume, cost, and delays |
| 13 | `report_suppliers` | Full supplier performance report view — KPIs, delay rates, relationship segments, account types |
| 14 | `report_shipments` | Full shipment report view — all six tables joined, enriched with delay severity, cost bands, and risk flags |

---

## 🧹 Data Quality & Cleaning

The dataset was intentionally generated with real-world data quality issues to simulate what analysts encounter in production environments. Script `06` resolves all of them systematically.

| Issue | Table | Resolution |
|---|---|---|
| Null and blank supplier names | `ref_suppliers` | Replaced with `'Unknown Supplier'` |
| Inconsistent country casing (`GERMANY`, `germany`) | `ref_suppliers` | Standardised to Title Case |
| Null transport mode on carriers | `ref_carriers` | Replaced with `'Unknown'`, casing standardised |
| Blank origin and destination cities | `ref_routes` | Replaced with `'Unknown'` |
| Missing `delay_days` where `actual_date` exists | `fact_shipments` | Recalculated using `DATEDIFF(DAY, promised_date, actual_date)` |
| Impossible dates (`actual_date < order_date`) | `fact_shipments` | Flagged as `'Data Error'` — excluded from all analysis |
| Null `shipment_cost`, `weight_kg`, `quantity` | `fact_shipments` | Replaced with `0.00` and flagged |

**Cleaning approach:** Every fix is preceded by a before-count and followed by an after-count. The final audit block confirms all issues return zero — ensuring the data is fully trustworthy before any analysis runs.

---

## 💡 Key Analytical Techniques Used

- ⚙️ **Window Functions** — `RANK()`, `DENSE_RANK()`, `NTILE()`, `LAG()`, `SUM() OVER()`, `AVG() OVER()`, `ROWS BETWEEN`
- 🧠 **CTEs** — Multi-level `WITH` clauses for base query → aggregation → final output
- 🔍 **Dirty Data Handling** — `ISNULL()`, `NULLIF()`, `TRIM()`, `TRY_CAST()` applied inline across all queries
- 📅 **Date Intelligence** — `DATETRUNC()`, `DATEDIFF()`, `FORMAT()`, `DATEPART()`
- 🔀 **Segmentation** — Multi-condition `CASE` logic for supplier tiers, delay severity, cost bands, route distance bands
- 📐 **Part-to-Whole** — Percentage contribution analysis using `SUM() OVER()` window aggregation
- 📈 **Year-over-Year** — Growth and decline tracking with `LAG()` and `PARTITION BY`
- 🏗️ **Star Schema** — Six-table fact and reference table design
- 🛡️ **Error Handling** — `TRY...CATCH` on every `BULK INSERT` for clean, debuggable data loading

---

## 📈 Key Findings

1. **~29% of all shipments arrive late** — the delay problem is structural, not seasonal, meaning it requires supplier and carrier intervention rather than seasonal capacity planning

2. **A small group of suppliers drive the majority of delays** — the bottom-quartile suppliers (`Critical` tier) have delay rates above 40%, yet many hold Gold or Platinum contracts — cost does not guarantee performance

3. **Warehouses operating above 90% capacity show significantly higher delay rates** — Nairobi East Africa Hub (93.8% utilisation, 34.4% delay rate) and Colombo Port Centre (90.1% utilisation, 32.7% delay rate) are the two biggest bottlenecks in the network

4. **The cost of delayed shipments represents a material share of total network spend** — high-value product categories such as Electronics and Pharmaceuticals carry the highest financial exposure when delayed

5. **Carrier actual OTD rates frequently fall short of contracted rates** — several carriers are underdelivering against their SLA commitments, meaning contract penalties may apply

---

## ✅ Recommendations

1. **Renegotiate or replace Critical-tier suppliers** — any supplier with a delay rate above 40% should face a formal performance review. If no improvement within 90 days, begin sourcing alternatives

2. **Redistribute load from overloaded warehouses** — Nairobi and Colombo are operating above safe capacity. Rerouting 15-20% of their volume to lower-utilisation facilities in the same region would directly reduce delay rates

3. **Enforce carrier SLA penalties** — carriers whose actual OTD rate falls more than 5 points below their contracted rate should be issued formal notices and considered for replacement on high-value routes

4. **Prioritise fragile, high-value product shipments on top-performing carriers** — Electronics and Pharmaceuticals delayed in transit represent the highest financial and reputational risk. These categories should be routed exclusively through Healthy-tier carriers

5. **Implement monthly supplier scorecards** — the `report_suppliers` view in this project provides the exact structure needed. Sharing delay rates, cost per on-time delivery, and performance tier with suppliers creates accountability and drives improvement

---

## 🛠️ Tools & Technologies

| Tool | Purpose |
|------|---------|
| SQL Server (SSMS) | Database engine and query execution |
| T-SQL | All data ingestion, cleaning, transformation and analysis |
| Python | Synthetic dataset generation with realistic dirty data |
| CSV Files | Raw data source for bulk loading into SQL Server |
| Power BI | Dashboard and visualisation layer |
| GitHub | Version control and project showcase |

---

## 🌟 About Me

Hi there! I'm **Collins Odoh**, a Computer and Information Systems student from BYU–Pathway Worldwide with a background in cybersecurity and a growing focus on data analytics. I build end-to-end analytics projects that go beyond dashboards — starting from raw, messy data and working through to structured insights and actionable business recommendations.

This project is part of my portfolio of real-world, domain-specific analytics work. I deliberately avoid generic tutorial topics and focus on industries and problems that reflect genuine business complexity.

📎 [LinkedIn](https://www.linkedin.com/in/collins-odoh-97b497382) — feel free to connect!

---

## 🛡️ License

This project is licensed under the MIT License. You are free to use, modify, and share it with proper attribution.

---

*Built with structure, business thinking, and a commitment to quality over quantity. 🚚*
## Dashboard Screenshots

### Dashboard Overview 1
![Dashboard Overview 1](Screenshot.dashboard%20overview1.png)

### Dashboard Overview 2
![Dashboard Overview 2](Screenshot.dashboard%20overview2.png)
