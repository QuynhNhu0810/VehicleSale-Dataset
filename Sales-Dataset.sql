
CREATE TABLE segment_score
(
    segment Varchar(50),
    scores Varchar(50)
)

select *
from dbo.segment_score

use Project
--1) Doanh thu theo từng ProductLine, Year  và DealSize--
select * 
from dbo.SALES_DATASET_RFM_PRJ
select sum(sales) as revenue
,productline
,year(orderdate) as year_order
,dealsize
from dbo.SALES_DATASET_RFM_PRJ
group by productline, year(orderdate), dealsize
--2) Đâu là tháng có bán tốt nhất mỗi năm?
select format(orderdate, 'MM-yyyy') as monthid
,sum(sales) as revenue
,count(ordernumber) as ordernumber
from dbo.SALES_DATASET_RFM_PRJ
group by format(orderdate, 'MM-yyyy')
order by 1,2 desc
--3) Product line nào được bán nhiều ở tháng 11?
select format(orderdate, 'MM-yyyy') as monthid
,count(ordernumber) as ordernumber
,productline
from dbo.SALES_DATASET_RFM_PRJ
where month(orderdate) = 11
group by format(orderdate, 'MM-yyyy'), productline
order by 1,2 desc
--4) Đâu là sản phẩm có doanh thu tốt nhất ở UK mỗi năm? 
select year_id,revenue, productline,
rank () over(order by revenue desc) as rank
from(
select year(orderdate) as year_id
,sum(sales) as revenue
,productline
,rank () over(partition by year(orderdate) order by sum(sales) desc) as ranking
from dbo.SALES_DATASET_RFM_PRJ
where country = 'UK' 
group by productline,year(orderdate)
) as r
where ranking = 1
--5) Ai là khách hàng tốt nhất, phân tích dựa vào RFM 
CREATE TABLE rfm_table (
	R DECIMAL,
	F DECIMAL,
	M DECIMAL,
    customername VARCHAR(1000),
    scores NUMERIC,
	segment VARCHAR(100),
	R_score NUMERIC,
	F_score NUMERIC,
	M_score NUMERIC,
)

;WITH rfm AS (
    SELECT 
        customername,
        DATEDIFF(day, MAX(orderdate), GETDATE()) AS R,
        COUNT(DISTINCT ordernumber) AS F,
        SUM(sales) AS M
    FROM dbo.SALES_DATASET_RFM_PRJ
    GROUP BY customername
),
rfm_score AS (
    SELECT 
		R,F,M,
        customername,
        NTILE(5) OVER (ORDER BY R DESC) AS R_score,
        NTILE(5) OVER (ORDER BY F) AS F_score,
        NTILE(5) OVER (ORDER BY M) AS M_score
    FROM rfm
),
rfm_final AS (
    SELECT 
		R,F,M,
		R_score,
		F_score,
		M_score,
        customername,
        CONCAT(R_score, F_score, M_score) AS rfm_score
    FROM rfm_score
)
INSERT INTO rfm_table (R,F,M,customername, scores,segment,R_score,F_score,M_score)
SELECT 
	a.R,a.F,a.M,
    a.customername,
    b.scores,
	b.segment,
	a.R_score,
	a.F_score,
	a.M_score
FROM rfm_final a
JOIN segment_score b ON a.rfm_score = b.scores
select * from rfm_table

