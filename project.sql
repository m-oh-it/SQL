-- i imported given datafile with name walmartsales_dataset and created schema as project

use project;
select * from walmartsales_dataset; 

------------------------------------------------------------------------------------------
/* Task 1: Identifying the Top Branch by Sales Growth Rate
Walmart wants to identify which branch has exhibited the highest sales growth over time. Analyze the total sales
for each branch and compare the growth rate across months to find the top performer. */
------------------------------------------------------------------------------------------


WITH MonthlySales AS (
    SELECT Branch, DATE_FORMAT(STR_TO_DATE(Date, '%d-%m-%Y'), '%Y-%m') AS SalesMonth, SUM(Total) AS TotalSales
    FROM walmartsales_dataset
    GROUP BY Branch, SalesMonth ),
SalesWithGrowth AS ( SELECT *, LAG(TotalSales) OVER (PARTITION BY Branch ORDER BY SalesMonth) AS PrevMonthSales,
        ROUND((TotalSales - LAG(TotalSales) OVER (PARTITION BY Branch ORDER BY SalesMonth)) / 
        NULLIF(LAG(TotalSales) OVER (PARTITION BY Branch ORDER BY SalesMonth), 0) * 100, 2) AS GrowthRate
        FROM MonthlySales)
SELECT Branch, ROUND(AVG(GrowthRate),2) AS `Avg Monthly Growth Rate`
FROM SalesWithGrowth
WHERE GrowthRate IS NOT NULL
GROUP BY Branch
ORDER BY `Avg Monthly Growth Rate` DESC
LIMIT 1;
/*
MonthlySales: Gets total sales per branch per month.
LAG(): Gets previous month's sales per branch.
GrowthRate: Calculates % growth from previous month.
AVG(GrowthRate): Averages growth over all months (ignoring NULL for the first month).
LIMIT 1: Returns the top-performing branch by average monthly sales growth.
*/

------------------------------------------------------------------------------------------
/* Task 2: Finding the Most Profitable Product Line for Each Branch
Walmart needs to determine which product line contributes the highest profit to each branch.The profit margin
should be calculated based on the difference between the gross income and cost of goods sold. */
------------------------------------------------------------------------------------------

WITH ProfitByBranch AS (SELECT Branch, `Product Line`,
        ROUND(SUM(`Gross Income` - COGS), 2) AS Profit,
        ROW_NUMBER() OVER (PARTITION BY Branch 
            ORDER BY SUM(`Gross Income` - COGS) DESC ) AS `Rank`
    FROM walmartsales_dataset
    GROUP BY Branch, `Product Line` )
SELECT Branch, `Product Line`, Profit
FROM ProfitByBranch
WHERE `Rank` = 1;



------------------------------------------------------------------------------------------
/* Task 3: Analyzing Customer Segmentation Based on Spending
Walmart wants to segment customers based on their average spending behavior. Classify customers into three
tiers: High, Medium, and Low spenders based on their total purchase amounts.*/
------------------------------------------------------------------------------------------

WITH Customer_Spending AS (SELECT `Customer ID`,ROUND(AVG(Total),2) AS avg_spending
FROM walmartsales_dataset
GROUP BY `Customer ID`)
SELECT`Customer ID`,avg_spending,
    CASE
        WHEN avg_spending < 300 THEN 'LOW'
        WHEN avg_spending BETWEEN 300 AND 340 THEN 'MEDIUM'
        ELSE 'HIGH'
	END AS Cust_spending_segment
FROM Customer_Spending
ORDER BY `Customer ID`;

------------------------------------------------------------------------------------------
/* Task 4: Detecting Anomalies in Sales Transactions
Walmart suspects that some transactions have unusually high or low sales compared to the average for the
product line. Identify these anomalies.*/
------------------------------------------------------------------------------------------
/*
To identify sales anomalies in Walmart's data, where some transactions have unusually high or low sales compared 
to the average for their product line, we will:
1.Compare each transaction's Total against the average ± 2 standard deviations (AVG ± 2 * STDDEV) per product line.
2.Flag values outside this range as anomalies.
*/


SELECT *,CASE 
    WHEN Total > (SELECT AVG(Total) + 2 * STDDEV(Total)
      FROM walmartsales_dataset
      WHERE `Product Line` = w.`Product Line`) THEN 'High Anomaly'
	WHEN Total < (SELECT AVG(Total) - 2 * STDDEV(Total)
      FROM walmartsales_dataset
      WHERE `Product Line` = w.`Product Line`) THEN 'Low Anomaly'
    END AS AnomalyStatus
FROM walmartsales_dataset w
WHERE Total > (SELECT AVG(Total) + 2 * STDDEV(Total)
        FROM walmartsales_dataset
        WHERE `Product Line` = w.`Product Line`)
   OR Total < (SELECT AVG(Total) - 2 * STDDEV(Total)
        FROM walmartsales_dataset
        WHERE `Product Line` = w.`Product Line`);


    
------------------------------------------------------------------------------------------
/* Task 5: Most Popular Payment Method by City
Walmart needs to determine the most popular payment method in each city to tailor marketing strategies.*/
------------------------------------------------------------------------------------------

WITH payment_tally AS (SELECT
    City,Payment,COUNT(Payment) AS transaction_tally,
    RANK() OVER (PARTITION BY City ORDER BY COUNT(Payment) DESC) AS payment_rank
FROM walmartsales_dataset
GROUP BY City, Payment)
SELECT
    City,Payment,transaction_tally
FROM payment_tally
WHERE payment_rank = 1;

------------------------------------------------------------------------------------------
/* Task 6: Monthly Sales Distribution by Gender
Walmart wants to understand the sales distribution between male and female customers on a monthly basis.*/
------------------------------------------------------------------------------------------

SELECT
    Gender,
    MONTH(STR_TO_DATE(Date, '%d-%m-%Y')) AS Month,
    ROUND(SUM(Total)) AS `Total Sales`,
    ROUND(SUM(Total) / SUM(SUM(Total)) OVER (
        PARTITION BY MONTH(STR_TO_DATE(Date, '%d-%m-%Y'))
    ) * 100, 2) AS Percentage
FROM walmartsales_dataset
GROUP BY Gender, MONTH(STR_TO_DATE(Date, '%d-%m-%Y'))
ORDER BY Gender, Month;


------------------------------------------------------------------------------------------
/* Task 7: Best Product Line by Customer Type
Walmart wants to know which product lines are preferred by different customer types(Member vs. Normal).*/
------------------------------------------------------------------------------------------

WITH Customer_preference AS (SELECT `Customer type`,`Product line`,ROUND(SUM(Total)) AS `Total Sales`,
    RANK() OVER (PARTITION BY `Customer type` ORDER BY SUM(Total) DESC) AS product_rank
FROM walmartsales_dataset
GROUP BY `Customer type`, `Product line`)
SELECT `Customer type`,`Product line`,`Total Sales`
FROM Customer_preference
WHERE product_rank = 1;

------------------------------------------------------------------------------------------
/* Task 8: Identifying Repeat Customers
Walmart needs to identify customers who made repeat purchases within a specific time frame (e.g., within 30 days).*/
------------------------------------------------------------------------------------------

SELECT DISTINCT a.`Customer ID`
FROM walmartsales_dataset a
JOIN walmartsales_dataset b 
  ON a.`Customer ID` = b.`Customer ID`
     AND STR_TO_DATE(b.Date, '%d-%m-%Y') > STR_TO_DATE(a.Date, '%d-%m-%Y')
     AND DATEDIFF(STR_TO_DATE(b.Date, '%d-%m-%Y'), STR_TO_DATE(a.Date, '%d-%m-%Y')) <= 30;

     
     
------------------------------------------------------------------------------------------
/* Task 9: Finding Top 5 Customers by Sales Volume
Walmart wants to reward its top 5 customers who have generated the most sales Revenue.*/
------------------------------------------------------------------------------------------


SELECT `Customer ID`, Round(SUM(Total),2) AS Sales_Revenue
FROM walmartsales_dataset
GROUP BY `Customer ID`
ORDER BY Sales_Revenue DESC
LIMIT 5;

------------------------------------------------------------------------------------------
/*Task 10: Analyzing Sales Trends by Day of the Week
Walmart wants to analyze the sales patterns to determine which day of the week brings the highest sales.*/
------------------------------------------------------------------------------------------

SELECT
    DAYNAME(STR_TO_DATE(Date, '%d-%m-%Y')) AS day_of_week,
    ROUND(SUM(Total)) AS total_sales
FROM walmartsales_dataset
GROUP BY day_of_week
ORDER BY total_sales DESC
LIMIT 1;



